#!/bin/bash

# runs dimsum on HPC. (activate using SLURM with the slurm_dimsum.sh script)
# Run this within the DiMSum directory and the mamba environment.
# Usage: ./run_dimsum.sh [run_name]

# options: local run vs slurm 
scratch_dir="/scratch/alpine/c838573989@colostate.edu/"

# data_dir="../data" # local data directory (for testing)
data_dir="${scratch_dir}/data_staging" # HPC data directory

# Set the run name, defaulting to "della_pilot_ez" if not provided
run_name="${1:-della_pilot_ez}"

# Set the paths for the parameter file, experiment design, fastq directory, and output directory
params_file="config/${run_name}.params"
experiment_design="config/${run_name}.txt"
fastq_dir="${data_dir}/${run_name}"
output_dir="${scratch_dir}/deepmut_variant_analysis/dimsum_results/${run_name}"

# file checks: 

# check parameter file and experiment design exists
if [[ ! -f "$params_file"  ]] || [[ ! -f "$experiment_design" ]]; then
    echo "Parameter file or experiment design not found: $params_file, $experiment_design" >&2
    exit 1
fi

# check for fastq dir exists and not empty
if [[ ! -d "$fastq_dir" ]] || [[ -z "$(ls -A $fastq_dir)" ]]; then
    echo "Fastq directory is empty or not found: $fastq_dir" >&2
    exit 1
fi


# The parameter file contains the shell variables used below; need to source it
source "$params_file"

# Convert the wildtype sequence and cutadapt sequences to uppercase to ensure consistency
wildtype_sequence=$(printf '%s' "$wildtype_sequence" | tr '[:lower:]' '[:upper:]')
cutadapt_5_first=$(printf '%s' "$cutadapt_5_first" | tr '[:lower:]' '[:upper:]')
cutadapt_5_second=$(printf '%s' "$cutadapt_5_second" | tr '[:lower:]' '[:upper:]')

mkdir -p "$output_dir"

# writing the command to run dimsum for quick port/test in HPC before running slurm
DiMSum --fastqFileDir "$fastq_dir" \
    --experimentDesignPath "$experiment_design" \
    --wildtypeSequence "$wildtype_sequence" \
    --stranded F \
    --cutadapt5First "$cutadapt_5_first" \
    --cutadapt5Second "$cutadapt_5_second" \
    -o "$output_dir" \
    --numCores 8


