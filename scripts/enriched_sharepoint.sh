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

## key variables ----------------------------------
scratch_dir="/scratch/alpine/$USER"
results_dir="${scratch_dir}/deepmut_variant_analysis/dimsum_results/enrichment_data"



module load rclone

output_dir="${results_dir}"
remote="onedrive_csu:Databases/Novogene NGS sequencing/pk_analysis_temp/enrichment_Or_frequency_tables/"

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
    echo "rclone failed: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - stage_start) / 60 )) minutes)" >&2

fi