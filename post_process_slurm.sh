#!/bin/bash

#SBATCH --nodes=1
#SBATCH --job-name=post-process-dimsum
#SBATCH --output=logs_slurm/post_%j.out
#SBATCH --error=logs_slurm/post_%j.err
#SBATCH --time=1:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=6G
#SBATCH --qos=cpu-normal
#SBATCH -p acpu

# direct the temp files to prevent unnecessary storage (SLURM_SCRATCH is a local scratch directory on the node)
export TMPDIR="${SLURM_SCRATCH}/.tmp"
mkdir -p "$TMPDIR"

# ------------------end of slurm stuff --------------

# Usage:
#   sbatch post_process_slurm.sh [run_name]
# Run all runs by default. If a run_name is provided, only that run will be processed.

source ~/.bashrc

set -euo pipefail

if [[ $# -gt 1 ]]; then
    echo "Usage: sbatch post_process_slurm.sh [run_name]" >&2
    exit 1
fi

## key variables ----------------------------------
scratch_dir="/scratch/alpine/$USER"
results_dir="${scratch_dir}/deepmut_variant_analysis/dimsum_results"

post_process_script="./scripts/post_process.R"

if [[ ! -d "$results_dir" ]]; then
    echo "Results directory not found: $results_dir" >&2
    exit 1
fi

if [[ ! -f "$post_process_script" ]]; then
    echo "Post-processing script not found: $post_process_script" >&2
    exit 1
fi

module load miniforge
mamba activate tidyverse 
# make sure to load a clean environment for latest R and tidyverse.

job_start=$(date +%s)
processed_count=0
failed_count=0
declare -a run_names=()
declare -A seen_runs=()

echo "Job started: $(date --iso-8601=seconds)"

if [[ $# -eq 1 ]]; then
    run_name="$1"
    search_dir="${results_dir}/${run_name}"
    if [[ ! -d "$search_dir" ]]; then
        echo "Run directory not found: $search_dir" >&2
        exit 1
    fi
    echo "Run name: $run_name"
else
    search_dir="$results_dir"
    echo "No run name provided; searching all run directories"
fi

echo "Searching for variant_data_parsed.tsv under: $search_dir"

while IFS= read -r -d '' input_file; do
    echo
    echo "Post-processing: $input_file"
    if Rscript --vanilla "$post_process_script" "$input_file"; then
        ((processed_count += 1))
        relative_input="${input_file#"$results_dir"/}"
        input_run_name="${relative_input%%/*}"
        if [[ -z "${seen_runs[$input_run_name]+x}" ]]; then
            run_names+=("$input_run_name")
            seen_runs["$input_run_name"]=1
        fi
        echo "Finished: $input_file"
    else
        ((failed_count += 1))
        echo "Failed: $input_file" >&2
    fi
done < <(find "$search_dir" -type f -name "variant_data_parsed.tsv" -print0 | sort -z)

if [[ "$processed_count" -eq 0 && "$failed_count" -eq 0 ]]; then
    echo "No variant_data_parsed.tsv files found under: $search_dir" >&2
    exit 1
fi

echo
echo "Post-processing complete: $processed_count succeeded, $failed_count failed"
echo "Elapsed: $(( ($(date +%s) - job_start) / 60 )) minutes"

## COPY RESULTS SECTION ----------------------------

echo "Copying results to sharepoint..."

module load rclone
rclone_failed_count=0

for run_name in "${run_names[@]}"; do
    output_dir="${results_dir}/${run_name}"
    remote="onedrive_csu:Databases/Novogene NGS sequencing/pk_analysis_temp/${run_name}"

    echo
    echo "Copying results to sharepoint: $remote"
    stage_start=$(date +%s)
    if rclone mkdir "$remote" &&
       rclone copy "$output_dir" "$remote" \
           --include 'processed_data*.csv' \
           --include 'variant_enrichment_data*.csv' \
           --include 'post_processing.log' \
           --ignore-checksum --ignore-size \
           --verbose --stats-one-line \
           --transfers=4 --checkers=8
    then
        echo "rclone finished: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - stage_start) / 60 )) minutes)"
    else
        ((rclone_failed_count += 1))
        echo "rclone failed for: $run_name" >&2
    fi
done

echo "Job finished: $(date --iso-8601=seconds) (total elapsed: $(( ($(date +%s) - job_start) / 60 )) minutes)"

if [[ "$failed_count" -gt 0 || "$rclone_failed_count" -gt 0 ]]; then
    echo "Job completed with failures: Rscript=$failed_count, rclone=$rclone_failed_count" >&2
    exit 1
fi
