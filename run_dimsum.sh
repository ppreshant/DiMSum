#!/bin/bash

# writing the command to run dimsum for quick port/test in HPC
# Note: save the WT sequence to a file and load it 

output_dir=results/della_pilot_ez
mkdir -p $output_dir

DiMSum --fastqFileDir ../data/ \
    --experimentDesignPath config/della_pilot_ez.txt \
    --wildtypeSequence "$(cat config/della_wt.txt)" \
    --stranded F \
    --cutadapt5First GTCTTTCAAACCACGGGACTAGTTCTAGTAGCTCATCAATTTCTAAGGATAAGATGATGATG \
    --cutadapt5Second GTTGCTGCTAGCGGGTAGAG \
    -o $output_dir \
    --numCores 3


