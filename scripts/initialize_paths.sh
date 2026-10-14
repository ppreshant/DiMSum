#!/bin/bash

# Create the local and scratch directories required by the HPC DiMSum scripts.
#
# Usage:
#   ./scripts/initialize_paths.sh [run_name]

set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [run_name]"
    echo "Create the directories required to run DiMSum on HPC."
    exit 0
fi

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [run_name]" >&2
    exit 1
fi

scratch_dir="/scratch/alpine/$USER"
data_dir="${scratch_dir}/data_staging"
output_base_dir="${scratch_dir}/deepmut_variant_analysis/dimsum_results/"
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p \
    "${repo_dir}/logs_slurm" \
    "${data_dir}/" \
    "${output_base_dir}"

echo "Created HPC DiMSum paths:"
echo "  Slurm logs:     ${repo_dir}/logs_slurm"
echo "  FASTQ staging:  ${data_dir}/"
echo "  DiMSum output:  ${output_base_dir}"
