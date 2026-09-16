#!/bin/bash

#SBATCH --nodes=1
#SBATCH --job-name=dimsum
#SBATCH --output=logs_slurm/%j.out
#SBATCH --error=logs_slurm/%j.err
#SBATCH --time=2:00:00          
#SBATCH --cpus-per-task=8
#SBATCH --mem=30G
#SBATCH --qos=cpu-normal
#SBATCH -p acpu

# direct the temp files to prevent unnecessary storage (SLURM_SCRATCH is a local scratch directory on the node)
export TMPDIR="${SLURM_SCRATCH}/.tmp"
mkdir -p "$TMPDIR"

# ------------------end of slurm stuff --------------

# source this file to help load modules (needed in non-interactive sessions)
source ~/.bashrc

# load modules
module load miniforge

# activate conda/mamba environment
mamba activate dimsum

set -euo pipefail

job_start=$(date +%s)
echo "Job started: $(date --iso-8601=seconds)"

# Run dimsum
run_name="${1:-della_pilot_ez}"
stage_start=$(date +%s)
echo "DiMSum started: $(date --iso-8601=seconds)"
./run_dimsum.sh "$run_name"
echo "DiMSum finished: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - stage_start) / 60 )) minutes)"

# key variables
scratch_dir="/scratch/alpine/c838573989@colostate.edu/"
output_dir="${scratch_dir}/deepmut_variant_analysis/dimsum_results/${run_name}"

# Create a compact, user-facing variant table after DiMSum completes.
merge_file="${output_dir}/DiMSum_Project/DiMSum_Project_variant_data_merge.tsv"
user_file="${output_dir}/variant_data_parsed.tsv"
stage_start=$(date +%s)
echo "Variant parsing started: $(date --iso-8601=seconds)"

# Run the Python script to parse the variant data
python scripts/parse_variant_data.py "$merge_file" "$user_file"

echo "Variant parsing finished: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - stage_start) / 60 )) minutes)"

# use rclone to copy the results to the cloud storage (if needed)
module load rclone
REMOTE="onedrive_csu:Databases/Novogene NGS sequencing/pk_analysis_temp/pk_analysis_temp/${run_name}"
rclone mkdir "$REMOTE"

echo "Copying results to sharepoint: \n$REMOTE"
stage_start=$(date +%s)
echo "rclone started: $(date --iso-8601=seconds)"

# rclone copy step
rclone copy "${output_dir}" "$REMOTE" --progress

echo "rclone finished: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - stage_start) / 60 )) minutes)"
echo "Job finished: $(date --iso-8601=seconds) (total elapsed: $(( ($(date +%s) - job_start) / 60 )) minutes)"