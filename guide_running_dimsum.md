_Note: this is a guide to run DiMSum locally_
# Running DiMSum locally

This guide describes the local workflow used in this repository. The commands below assume the repository is located at:

```text
~/bioinformatics/deepmut_variant_analysis/DiMSum
```

## Prerequisites
Prerequisites (already done on Prashant's linux box)

Install Conda or Mamba, then create the DiMSum environment from the repository root. This only works with conda/mamba (and not pixi).

Create the environment from `dimsum_full.yaml`:
```bash
cd ~/bioinformatics/deepmut_variant_analysis/DiMSum
conda env create -f dimsum_full.yaml
conda activate dimsum
```

Check that DiMSum is available before starting a run:

```bash
command -v DiMSum
DiMSum --help
```

## Set up the data

Store each experiment in a directory under `../data`. The directory name becomes the run name. For example:

```text
deepmut_variant_analysis/
├── data/
│   └── della_pilot_ez/
│       ├── GS2436UQ5AF_R1_001.fastq.gz
│       └── GS2436UQ5AF_R2_001.fastq.gz
└── DiMSum/
```

The FASTQ filenames must match the `pair1` and `pair2` columns in the experiment design file. The local launcher expects the FASTQ directory to exist and contain at least one file.

## Configure a run

### Create config/..params and ..txt
Create a parameter file and an experiment design file in `config/`. Their filenames must use the same run name:

```text
config/<run_name>.params
config/<run_name>.txt
```

For a new experiment, copy the closest existing configuration and edit in VScode (_good for AI cleanup and error checking_) or any text editors like notepad/feathercalc/vim:

Use the wrapper to duplicate the desired config: defaults to duplicate `theoAptzNNN_lokya`
```sh
./scripts/duplicate_config.sh <new_config_name> [source_config_name]
```

Alternatively, for manual copy 
```bash
cp config/della_pilot_ez.params config/my_experiment.params
cp config/della_pilot_ez.txt config/my_experiment.txt
```

### Update config 
- Update `config/my_experiment.params` with the experiment-specific `wildtype_sequence` and internal primer sequences for cutadapt (_these are the ends of the current raw reads that need to be trimmed. They will be the first primer used to amplify the sample (without the tails) and don't include the index sequences etc. added in the 2nd PCR_). 

- Update `config/my_experiment.txt` so its FASTQ filenames and sample metadata match the files in `../data/my_experiment/`. See [FILEFORMATS.md](docs/FILEFORMATS.md) for the experiment design format.
  - You can use AI generate this config: provide the current config (duplicated), the table of samples list and the `ls ../data/<current_experiment>` output with the list of files and AI does a pretty decent job.


## Run DiMSum

Run the launcher from the `DiMSum` directory while the DiMSum environment is active:

Activating mamba
```bash
cd ~/bioinformatics/deepmut_variant_analysis/DiMSum
mamba activate dimsum
```
- Running dimsum locally

```sh
./run_dimsum.sh <experiment_name>
```

Note: There is an `--environment local` option which we skip, since it is the default.

For doing a test run with the example configuration already in the repository, you can leave the `experiment_name` blank which defaults to this

```bash
./run_dimsum.sh della_pilot_ez
```

Additional DiMSum command-line options can be placed after the run name and are passed through to `DiMSum`:

```bash
./run_dimsum.sh my_experiment --someDiMSumOption value
```

The local launcher uses three CPU cores to reduce memory usage. It also retains intermediate files.

## Outputs

Results are written to:

```text
DiMSum/results/<run_name>/
```

Before starting DiMSum, the launcher checks that both configuration files exist and that `../data/<run_name>/` is present and non-empty. If either check fails, verify the run name, filenames, and current working directory.

# Issues? make a Github issue thread!
If you encounter any issues the best way to contact Prashant is by documenting the error and the context of what you ran on a github issue thread here: https://github.com/ppreshant/DiMSum/issues

# Running DiMSum on HPC

## Prerequisites

0. Make an HPC account using the guide doc: [Individual Set-Up for the Alpine HPC Cluster](https://colostate.sharepoint.com/:w:/r/sites/Arjun-Lab/_layouts/15/Doc.aspx?sourcedoc=%7B60fdbc00-1285-4674-a351-0cf05258f13f%7D&action=edit&wdPid=6c9094b4) 
  - Do skim over the storage guidelines to get an idea of where the wrapper scripts are storing things. [Storing files on Alpine HPC cluster](https://colostate.sharepoint.com/:w:/r/sites/Arjun-Lab/_layouts/15/Doc.aspx?sourcedoc=%7BC33E462E-CC39-465D-B34C-6C623A540535%7D&file=Storing%20Files%20on%20Alpine%20HPC%20Cluster.docx&action=default&mobileredirect=true&wdwpf=doclib-t)

1. Make a github account for yourself as a good practice. _This is not required to just run dimsum per-se_, but will come in handy when you need to make any changes (_which will happen inevitably_)

## Setup
_You run these only once per HPC account!_

0. Make a directory to store DimSum code with some organization in `/home/$USER` directory (which is the default `~` when you login)
```sh
mkdir deepmut_variant_analysis
cd deepmut_variant_analysis
``` 

1. Clone the repository fork from Prashant's github [fork](https://github.com/ppreshant/DiMSum) using this code. 
  - Note that my repo has many convenience wrapper scripts to work in HPC and the original repo doesn't have these. (https://github.com/lehner-lab/DiMSum/)
  - This url is available when clicking the green `<> Code>` button on my github link
```sh
git clone https://github.com/ppreshant/DiMSum.git
```
_If you intend to make changes to the repo, I recommend later changing the repo URL to the ssh url (`git@github.com:ppreshant/DiMSum.git`) after you make yourself an ssh key on the HPC_. References: [github and ssh](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) > 3,4 are relevant.

Now cd into the newly downloaded dimsum directory
```sh
cd DiMSum
```

2. initialize mamba environments for dimsum and tidyverse (post processing using `dplyr`). Run this slurm script
  - Note that slurm scripts run computational tasks in a batch/queue depending on the priority allocations. Read about allocations in the [allocations section/CURC documentation](https://curc.readthedocs.io/en/latest/clusters/alpine/allocations.html#fairshare-priority-and-allocations)

```sh
sbatch scripts/initialize_mamba_environments.sh
```

This should take about 15 minutes to run and will create the mamba environments in your home directory. You can check the status of the job using `squeue -u $USER` and check the logs in `logs_slurm/mamba_<jobid>.out` and `logs_slurm/mamba_<jobid>.err` using the `less` command. If the job fails, check the error log and try to fix the issue. If you are unable to fix it, make a github issue thread with the error log and context of what you ran.
```sh
less logs_slurm/mamba_<jobid>.out
```

3. Create the Slurm log, FASTQ staging, and DiMSum output's base directories by running the path initialization helper from the repository root:
```sh
bash ./scripts/initialize_paths.sh
```

Before submitting a job for a particular dataset 
1. You will need to manually create subdirectoreies for each `<experiment_name>`. 
2. copy the experiment's FASTQ files into `/scratch/alpine/$USER/data_staging/<experiment_name>/`.

## Download and pre-process data
To download data from novogene, login to the HPC's scratch data directory and follow the instructions in the email to download the data. The data will be in a compressed format `.fq.gz` which will save a lot of space ~10x. _don't compress this file; code can read it directly_.

Side note: To download published data from SRA, you can use the `sra-tools` package. 



## Running dimsum
..

