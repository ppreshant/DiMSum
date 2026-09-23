#!/bin/bash

# runs dimsum on HPC. (activate using SLURM with the slurm_dimsum.sh script)
# Run this within the DiMSum directory and the mamba environment.
# Usage: ./run_dimsum.sh [--environment local|hpc] [run_name] [dimsum_option ...]

# Set the run name, defaulting to "della_pilot_ez" if not provided
environment="local"
if [[ "${1:-}" == "--environment" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "--environment requires local or hpc" >&2
        exit 1
    fi
    environment="$2"
    shift 2
fi

run_name="della_pilot_ez"
if [[ $# -gt 0 && "$1" != --* ]]; then
    run_name="$1"
    shift
fi
dimsum_args=("$@")

# Select paths for local execution or HPC execution.
case "$environment" in
    local)
        data_dir="../data"
        output_dir="results/${run_name}"
        ;;
    hpc)
        scratch_dir="/scratch/alpine/$USER"
        data_dir="${scratch_dir}/data_staging"
        output_dir="${scratch_dir}/deepmut_variant_analysis/dimsum_results/${run_name}"
        ;;
    *)
        echo "Invalid environment: $environment (use local or hpc)" >&2
        exit 1
        ;;
esac

# Set the paths for the parameter file, experiment design, fastq directory, and output directory
params_file="config/${run_name}.params"
experiment_design="config/${run_name}.txt"
fastq_dir="${data_dir}/${run_name}"
# num_cores="${SLURM_CPUS_PER_TASK:-3}" # # not using; trying to fix OOM issues
num_cores=3 # set to 3 cores to avoid OOM issues

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
    --stranded F --sequenceType "noncoding" \
    --maxSubstitutions 25 --indels 'all' \
    --cutadapt5First "$cutadapt_5_first" \
    --cutadapt5Second "$cutadapt_5_second" \
    -o "$output_dir" \
    --numCores "$num_cores" \
    --retainIntermediateFiles=T \
    "${dimsum_args[@]}"


