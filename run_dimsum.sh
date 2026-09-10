#!/bin/bash

# writing the command to run dimsum for quick port/test in HPC
# Note: save the WT sequence to a file and load it 

DiMSum --fastqFileDir ../data/ \
    --experimentDesignPath della_pilot_ez.txt \
    --wildtypeSequence "$(cat ./della_wt.txt)" \
    -o ../results/della_pilot_ez

