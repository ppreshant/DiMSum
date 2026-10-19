#!/bin/bash

#SBATCH --nodes=1
#SBATCH --job-name=dimsum
#SBATCH --output=logs_slurm/%j.out
#SBATCH --error=logs_slurm/%j.err
#SBATCH --time=2:00:00          
#SBATCH --cpus-per-task=12
#SBATCH --mem=40G
#SBATCH --qos=cpu-normal
#SBATCH -p acpu

# direct the temp files to prevent unnecessary storage (SLURM_SCRATCH is a local scratch directory on the node)
export TMPDIR="${SLURM_SCRATCH}/.tmp"
mkdir -p "$TMPDIR"

# ------------------end of slurm stuff --------------

# Usage:
#   sbatch slurm_dimsum.sh [run_name] [--fastq-dir folder] [--section section [section ...]] [-- dimsum_option ...]
# Run all sections by default. Valid section keywords are: dimsum, parse, copy.
# Examples:
#   sbatch slurm_dimsum.sh
#   sbatch slurm_dimsum.sh della_pilot_ez --section dimsum parse
#   sbatch slurm_dimsum.sh my_experiment --fastq-dir my_fastq_folder --section dimsum
#   sbatch slurm_dimsum.sh della_pilot_ez --section copy
#   sbatch slurm_dimsum.sh della_pilot_ez --section dimsum -- --startStage 4
#
# --fastq-dir is an optional folder name under the HPC data staging directory.
# It defaults to the run name and must be a folder name, not a full path.

# source this file to help load modules (needed in non-interactive sessions)
source ~/.bashrc

run_name="della_pilot_ez"
sections=()
section_option_seen=false
fastq_tip_folder=""
dimsum_args=()

if [[ $# -gt 0 && "$1" != --* ]]; then
	run_name="$1"
	shift
fi

while [[ $# -gt 0 ]]; do
	case "$1" in
		--)
			shift
			dimsum_args=("$@")
			break
			;;
		--section)
			section_option_seen=true
			shift
			while [[ $# -gt 0 && "$1" != --* ]]; do
				IFS=',' read -ra requested_sections <<< "$1"
				sections+=("${requested_sections[@]}")
				shift
			done
			;;
		--section=*)
			section_option_seen=true
			IFS=',' read -ra requested_sections <<< "${1#*=}"
			sections+=("${requested_sections[@]}")
			shift
			;;
		--fastq-dir)
			if [[ $# -lt 2 ]]; then
				echo "--fastq-dir requires a folder name" >&2
				exit 1
			fi
			fastq_tip_folder="$2"
			shift 2
			;;
		--fastq-dir=*)
			fastq_tip_folder="${1#*=}"
			shift
			;;
		--help|-h)
			echo "Usage: sbatch slurm_dimsum.sh [run_name] [--fastq-dir folder] [--section section [section ...]] [-- dimsum_option ...]"
			echo "Sections: dimsum, parse, copy (all run by default)"
			echo "--fastq-dir sets the FASTQ folder under the HPC data staging directory (defaults to run_name)"
			exit 0
			;;
		--*)
			echo "Unknown option: $1" >&2
			exit 1
			;;
		*)
			echo "Unexpected argument: $1" >&2
			exit 1
			;;
	esac
done

if [[ -z "$fastq_tip_folder" ]]; then
	fastq_tip_folder="$run_name"
fi
if [[ "$fastq_tip_folder" == */* ]]; then
	echo "--fastq-dir must be a folder name, not a path: $fastq_tip_folder" >&2
	exit 1
fi

if [[ "$section_option_seen" == true && ${#sections[@]} -eq 0 ]]; then
	echo "--section requires one or two section keywords." >&2
	exit 1
fi

if [[ ${#sections[@]} -gt 2 ]]; then
	echo "A maximum of two sections may be selected." >&2
	exit 1
fi

run_section=true
if [[ ${#sections[@]} -gt 0 ]]; then
	run_section=false
	for section in "${sections[@]}"; do
		case "$section" in
			dimsum|parse|copy) ;;
			*)
				echo "Invalid section: $section (use dimsum, parse, or copy)" >&2
				exit 1
				;;
		esac
	done
fi

section_selected() {
	if [[ "$run_section" == true ]]; then
		return 0
	fi
	local section
	for section in "${sections[@]}"; do
		[[ "$section" == "$1" ]] && return 0
	done
	return 1
}

## key variables ----------------------------------
scratch_dir="/scratch/alpine/$USER"
output_dir="${scratch_dir}/deepmut_variant_analysis/dimsum_results/${run_name}"

# load modules and activate the environment used by the selected sections
module load miniforge
mamba activate dimsum
set -euo pipefail

job_start=$(date +%s)
echo "Job started: $(date --iso-8601=seconds)"


## DIMSUM SECTION ----------------------------------

if section_selected dimsum; then
	# Run dimsum
	stage_start=$(date +%s)
	echo "DiMSum started: $(date --iso-8601=seconds)"
	./run_dimsum.sh --environment hpc "$run_name" --fastq-dir "$fastq_tip_folder" "${dimsum_args[@]}"
	echo "DiMSum finished: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - stage_start) / 60 )) minutes)"
fi


## PARSE VARIANT DATA SECTION ----------------------

if section_selected parse; then
	
	# Create a compact, user-facing variant table after DiMSum completes.
	# Select: key nucleotide columns and add count frequencies and percentages.
	merge_file="${output_dir}/DiMSum_Project/DiMSum_Project_variant_data_merge.tsv"
	user_file="${output_dir}/variant_data_parsed.tsv"
	stage_start=$(date +%s)
	echo "Variant parsing started: $(date --iso-8601=seconds)"

	# Run the Python script to parse the variant data
	python scripts/parse_variant_data.py "$merge_file" "$user_file"

	echo "Variant parsing finished: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - stage_start) / 60 )) minutes)"

	# post_processing on variant data
	# Filter: Drop low count variants in input (0 or 1 counts) 
	# Calculations: Calculates enrichment and leak based on frequencies in input, enriched and no inducer selection cols.
	post_process_script="./scripts/post_process.R"
	if [[ ! -f "$post_process_script" ]]; then
		echo "Post-processing failed: script not found: $post_process_script" >&2
		exit 1
	fi
	if [[ ! -f "$user_file" ]]; then
		echo "Post-processing failed: parsed variant file not found: $user_file" >&2
		exit 1
	fi
	if ! mamba activate tidyverse; then
		echo "Post-processing failed: could not activate the tidyverse environment." >&2
		exit 1
	fi
	if ! command -v Rscript >/dev/null 2>&1; then
		echo "Post-processing failed: Rscript is not available in the tidyverse environment." >&2
		exit 1
	fi

	post_process_start=$(date +%s)
	if Rscript --vanilla "$post_process_script" "$user_file"; then
		echo "Post-processing complete: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - post_process_start) / 60 )) minutes)"
	else
		post_process_status=$?
		echo "Post-processing failed with exit status ${post_process_status}: $post_process_script $user_file" >&2
		echo "Check the post-processing log alongside the input file: ${user_file%/*}/post_processing.log" >&2
		exit "$post_process_status"
	fi

fi


## COPY RESULTS SECTION ----------------------------

if section_selected copy; then
	# use rclone to copy the results to the cloud storage (if needed)
	module load rclone
	REMOTE="onedrive_csu:Databases/Novogene NGS sequencing/pk_analysis_temp/${run_name}"
	rclone mkdir "$REMOTE"

	echo "Copying results to sharepoint: $REMOTE"
	stage_start=$(date +%s)
	echo "rclone started: $(date --iso-8601=seconds)"

	# rclone copy step 
	rclone copy "${output_dir}" "$REMOTE" \
    --ignore-checksum --ignore-size \
    --verbose --stats-one-line \
    --transfers=4 --checkers=8 
    # note: (don't check file size on transfer, sharepoint side processing issue)

	echo "rclone finished: $(date --iso-8601=seconds) (elapsed: $(( ($(date +%s) - stage_start) / 60 )) minutes)"
	echo "Job finished: $(date --iso-8601=seconds) (total elapsed: $(( ($(date +%s) - job_start) / 60 )) minutes)"
fi