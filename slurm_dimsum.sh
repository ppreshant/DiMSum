#!/bin/bash

#SBATCH --nodes=1
#SBATCH --job-name=dimsum
#SBATCH --output=logs_slurm/%j.out
#SBATCH --error=logs_slurm/%j.err
#SBATCH --time=2:00:00          
#SBATCH --cpus-per-task=8
#SBATCH --mem=6G
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

# Run dimsum
run_name="${1:-della_pilot_ez}"
./run_dimsum.sh "$run_name"

# Create a compact, user-facing variant table after DiMSum completes.
merge_file="results/${run_name}/DiMSum_Project/DiMSum_Project_variant_data_merge.tsv"
user_file="results/${run_name}/variant_data_parsed.tsv"
python scripts/parse_variant_data.py "$merge_file" "$user_file"
