#!/bin/bash

#SBATCH --nodes=1
#SBATCH --job-name=dimsum
#SBATCH --output=logs_slurm/%j.out
#SBATCH --error=logs_slurm/%j.err
#SBATCH --time=1:00:00          
#SBATCH --cpus-per-task=4 
#SBATCH --mem=8G
#SBATCH --qos=cpu-normal
#SBATCH -p acpu

# direct the temp files to prevent unnecessary storage (SLURM_SCRATCH is a local scratch directory on the node)
export TMPDIR="${SLURM_SCRATCH}/.tmp"
mkdir -p "$TMPDIR"

# ------------------end of slurm stuff --------------

# source this file to help load modules (needed in non-interactive sessions)
source ~/.bashrc

# defaults + take in command line args for run name
run_name="della_enriched_library_lokya"
fastq_tip_folder=""

if [[ $# -gt 0 && "$1" != --* ]]; then
	run_name="$1"
	shift
fi

dimsum_file="${output_dir}/DiMSum_Project/DiMSum_Project_variant_data_merge.tsv"
post_process_script="./scripts/split_multiinputs.R"

module load miniforge
mamba activate tidyverse

post_process_start=$(date +%s)
if Rscript --vanilla "$post_process_script" "$dimsum_file"; then
  echo "Post-processing complete: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - post_process_start) / 60 )) minutes)"
else
  post_process_status=$?
  echo "Post-processing failed with exit status ${post_process_status}: $post_process_script $dimsum_file" >&2
  echo "Check the post-processing log alongside the input file: ${dimsum_file%/*}/post_processing.log" >&2
  exit "$post_process_status"
fi


# if section_selected copy; then
# use rclone to copy the results to the cloud storage (if needed)
module load rclone
REMOTE="onedrive_csu:Databases/Novogene NGS sequencing/pk_analysis_temp/${run_name}"
rclone mkdir "$REMOTE"

echo "Copying results to sharepoint: $REMOTE"
stage_start=$(date +%s)
echo "rclone started: $(date --iso-8601=seconds)"

# rclone copy step 
rclone copy "${output_dir}" "$REMOTE" \
--include-from="scripts/files_to_copy.rclone" \
  --ignore-checksum --ignore-size \
  --verbose --stats-one-line \
  --transfers=4 --checkers=8 
  # note: (don't check file size on transfer, sharepoint side processing issue)

echo "rclone finished: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - stage_start) / 60 )) minutes)"
echo "Job finished: $(date --iso-8601=seconds) (total elapsed: $(( ($(date +%s) - job_start) / 60 )) minutes)"
# fi