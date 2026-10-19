#!/bin/bash

#SBATCH --nodes=1
#SBATCH --job-name=initialize-mamba-envs
#SBATCH --output=logs_slurm/mamba_%j.out
#SBATCH --error=logs_slurm/mamba_%j.err
#SBATCH --time=1:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=6G
#SBATCH --qos=cpu-normal
#SBATCH -p acpu

# direct the temp files to prevent unnecessary storage (SLURM_SCRATCH is a local scratch directory on the node)
export TMPDIR="${SLURM_SCRATCH}/.tmp"
mkdir -p "$TMPDIR"

# ------------------end of slurm stuff --------------

## DimSum environment setup script ---------

# load modules and create environment for DiMSum
module load miniforge
mamba env create -f envs/dimsum_full.yaml

## tidyverse environment setup script ---------
# load modules and create environment for tidyverse
mamba env create -f envs/tidyverse.yaml

# check if the tidyverse environment was created successfully
mamba list r-tidyverse
