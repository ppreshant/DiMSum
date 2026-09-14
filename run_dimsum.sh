#!/bin/bash

# writing the command to run dimsum for quick port/test in HPC
# Usage: ./run_dimsum.sh [run_name]
run_name="${1:-della_pilot_ez}"
params_file="config/${run_name}.params"
experiment_design="config/${run_name}.txt"
output_dir="results/${run_name}"

if [[ ! -f "$params_file" ]]; then
    echo "Parameter file not found: $params_file" >&2
    exit 1
fi

source "$params_file"

mkdir -p "$output_dir"

DiMSum --fastqFileDir ../data/ \
    --experimentDesignPath "$experiment_design" \
    --wildtypeSequence "$wildtype_sequence" \
    --stranded F \
    --cutadapt5First "$cutadapt_5_first" \
    --cutadapt3First "$cutadapt_3_first" \
    --cutadapt5Second "$cutadapt_5_second" \
    --cutadapt3Second "$cutadapt_3_second" \
    -o "$output_dir" \
    --numCores 7


