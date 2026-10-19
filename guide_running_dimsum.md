# Running DiMSum on HPC
_refer to the section below for local run (without slurm)_

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
- To download data from novogene:
 login to the HPC's scratch data directory and follow the instructions in the email to download the data. The data will be in a compressed format `.fq.gz` which will save a lot of space ~10x. _don't compress this file; code can read it directly_.

- Standardize fastq data to R1/R2 format.
 Merge the data files seprated by flowcells/lanes into the standard R1/R2 paired-end format. This is done using the `cat` command in linux. For example, if you have two flowcells for a sample, you can merge them as follows:

```sh
sbatch scripts/merge_lanes_fastq.sh <experiment_name>
``` 

_Side note_: To download published data from SRA, you can use the `sra-tools` package available through the `conda`/`mamba` package manager.

- **Important**: Backup the data to Sharepoint using the `transfer_to_sharepoint_fastq_v3.sh` script. This will copy the data to the Sharepoint directory and preserve the directory structure. The script uses `rclone` to transfer the data. Make sure to modify the paths: `REMOTE` and `LOCAL` in the script to point to the correct directories. Definitely use the `--dry-run` option first to see what files will be transferred without actually transferring them.
  - You can check the status of the job using `squeue -u $USER` and check the logs in `logs_slurm/` using the `less` command. If the job fails, check the error log and try to fix the issue. If you are unable to fix it, make a github issue thread with the error log and context of what you ran.

For dry run
```sh
sbatch scripts/transfer_to_sharepoint_fastq_v3.sh --dry-run
```

For the final transfer
```sh
sbatch scripts/transfer_to_sharepoint_fastq_v3.sh
```

(**important**): The data in `/scratch/alpine/$USER/data_staging/<experiment_name>/` is the working copy and it will be deleted every couple months automatically. 


## Running dimsum

### Configure the run
- Create a parameter file and an experiment design file in `config/`. Their filenames must use the same run name:
See section above in for details: local run/[Configure a run](#configure-a-run)


### Launch dimsum
Launch the dimsum run using the slurm script. This will submit a job to the HPC queue and run dimsum on the allocated resources. The job will run in the background and you can check the status of the job using `squeue -u $USER`. The logs will be written to `logs_slurm/dimsum_<jobid>.out` and `logs_slurm/dimsum_<jobid>.err`. You can check the logs using the `less` command.

```sh
sbatch slurm_dimsum.sh <experiment_name>
``` 
- Check the section below for additional options to pass to the dimsum command.
- Tips: for any errors, do try a couple times and use AI/stackoverflow help to debug. If you are unable to fix it, make a github issue thread with the error log and context of what you ran.

## Additional command-line options

### Slurm script additional command-line options
The slurm script accepts the following options:

- `<experiment_name>`: optional run name. If omitted, the default is
  `della_pilot_ez`.
- `--section <section> [<section> ...]`: run only selected sections instead of
  the complete workflow. The available sections are:
  - `dimsum`: run the DiMSum analysis.
  - `parse`: parse the variant data and run post-processing.
  - `copy`: copy the results to SharePoint using `rclone`.
- `--section=<section>[,<section> ...]`: equivalent comma-separated form of
  `--section`.
- `--help`: print the usage message and available sections.

At most two sections can be selected. For example:

```sh
# Run only DiMSum and variant parsing/post-processing
sbatch slurm_dimsum.sh <experiment_name> --section dimsum parse

# Run only the copy step
sbatch slurm_dimsum.sh <experiment_name> --section copy

# Equivalent comma-separated syntax
sbatch slurm_dimsum.sh <experiment_name> --section=dimsum,parse
```

### DiMSum additional command-line options
Additional arguments for the `DiMSum` command must follow `--`. Arguments
before `--` are interpreted by the Slurm wrapper; arguments after `--` are
passed unchanged to `DiMSum`.

For example, to run DiMSum with the `--no-plot` option, you can use the following command:

```sh
sbatch slurm_dimsum.sh <experiment_name> -- --no-plot
```

For a list of all available options, you can navigate the documentation on the DiMSum repo [arguments.md](https://github.com/lehner-lab/DiMSum/blob/master/docs/ARGUMENTS.md) file.

Or you can access the same information using the `DiMSum --help` command for a list of all available options. You can also use the `--help` option with the slurm script to see the available options.


## Navigation on HPC
- (_prerequisite_) Make sure to clone the hpc_utils repository in your home directory. This repository contains useful scripts and aliases for navigating the HPC. You can clone it using the following command:
```sh
git clone https://github.com/ppreshant/hpc_utils.git
```
  - Follow the instructions in that readme to set up the aliases and scripts. The aliases are defined in the `~/.bashrc` file and are available after you login to the HPC. You can use the `alias` command to list all the available aliases.

- Use the shortcut aliases to navigate to the relevant directories. 
  - `repo_dim` to navigate to the DiMSum repository directory (with the code).
  - `data_dim` to navigate to the data staging directory (with the FASTQ files) in `scratch`.
  - `results_dim` to navigate to the DiMSum results directory (with the output files) in `scratch`.

```sh
cd_dimsum
```

**Tips**
- To check the status of your jobs, use the `squeue -u $USER`
- To check the logs of your jobs, use the `less` command on the log files in `logs_slurm/`. For example, to check the logs of a job with jobid 12345, use:
```sh
less logs_slurm/dimsum_12345.out
```

# Running DiMSum locally
This guide describes the workflow to run dimsum locally (without slurm). This workflow is partial and not fully complete. It is recommended to run dimsum on the HPC for large datasets. The local workflow is useful for small datasets or for testing purposes. _(ask to borrow Prashant's linux laptop for a local run if for quick testing and debugging)_.

The commands below assume the repository is located at:

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

Before running DiMSum, you need to feed in a parameter file and an experiment design file in `config/` with appropriate information for the experiment. 

Files: 
1. config/<run_name>.params
2. config/<run_name>.txt

The filenames must use the same run name as the data directory. For example, for the `della_pilot_ez` experiment, you need `config/della_pilot_ez.params` and `config/della_pilot_ez.txt`. The local launcher expects these files to exist and be readable.

For a new experiment, copy the closest existing configuration and edit in VScode or use Claude.AI etc. assistance. You can manually edit in any text editors like notepad/feathercalc/vim in your personal computer and copy the files to the HPC using `scp` command (`scp <local_file> <username>@<hpc_address>:<remote_path>`):

### Create template config files
Use the wrapper script to duplicate the desired config: defaults to duplicate the config from run:`theoAptzNNN_lokya` as the source config. You can also specify a different source config name as the second argument. The new config files will be created in `config/` with the new run name.
```sh
./scripts/duplicate_config.sh <new_config_name> [source_config_name]
```

### Modify config: Logistics (method 1)
To edit these files directly on the HPC, you can use the `vim` command. Follow along in the section below and skip the method 2 below if you are comfortable with `vim` or would like to learn it quick. An alternative to `vim`, is the `nano` command if that is more familiar to you.

- To copy file content from the HPC to clipboard, you can use the `cat` command to display the file content and then copy it from the terminal with this shortcut. For example, 
```bash
cat config/<run_name>.params
```
  - Then paste it into a text editor on your local machine (in the claude prompt that you will edit)
- To copy file content from your local machine to the HPC, copy it to your clipboard and paste it into the current file with the `vim` command. For example, to edit the params file:
```bash
vim config/<run_name>.params
```
  1. Delete the existing content by pressing `dG` (`d-shift-G` to delete to end of file) 
  2. Now press `i` to enter insert mode, then paste the content from your clipboard. 
  3. After pasting, press `Esc` to exit insert mode, then type `:wq` and press `Enter` to save and exit.


### Modify config: Logistics (method 2)
Alternatively, the best way to edit these files is to download them locally and edit in VScode or any text editor. Then upload the files back to the HPC.

**Download**
1. Find the path of the files using realpath command:
```sh
realpath config/<run_name>.params
```
2. Now open a new terminal in your local machine and use the `scp` command to download the files. For example, if your HPC username is `myusername` and the HPC address is `hpc.colostate.edu`, you can use the following commands to download them to the home directory of your local machine:
```bash
scp <myusername>@<hpc_path>:<path_to_params_file> .
scp <myusername>@<hpc_path>:<path_to_txt_file> .
``` 
3. Edit the files locally and save the changes using the documentation below. 

**Upload**
Then upload the files back to the HPC using the `scp` command:
```bash
scp ./<run_name>.params <myusername>@<hpc_path>:<path_to_params_file> .
scp ./<run_name>.txt <myusername>@<hpc_path>:<path_to_txt_file> .
```

### Modify config/params
Update `config/my_experiment.params` with the experiment-specific `wildtype_sequence` and internal primer sequences for cutadapt (_these are the ends of the current raw reads that need to be trimmed. They will be the first primer used to amplify the sample (without the tails) and don't include the index sequences etc. added in the 2nd PCR_).
- Do verify if the primers are correct by checking the first read or two in the Input/any FASTQ.gz file with an alignment to benchling. You can use `zcat` to view the first few lines of a gzipped FASTQ file:
```bash
zcat ../data/my_experiment/GS2436UQ5AF_R1_001.fastq.gz | head -n 8
```

### Modify config/txt
Update `config/my_experiment.txt` so its FASTQ filenames and sample metadata match the files in `../data/my_experiment/`. See [FILEFORMATS.md](docs/FILEFORMATS.md) for the experiment design format.

- You can use AI (VScode/Claude) to generate this config: provide the current config (for format template), the table of samples list and the `ls ../data/<current_experiment>` output with the list of files and AI does a pretty decent job. The AI helps autodetect and match the patterns from the human readable sample names to the FASTQ filenames. You can then manually verify the output and make any necessary adjustments.
  
Use this format to ask AI to do the config update:
Paste this prompt into a text file, make edits by copy pasting content from the current config file and list of FASTQ files in the HPC. Then ask AI to generate the new config file. You can then copy paste the output into the new config file, verify it (excel works  best) and replace the content of the file in HPC.

```text
Edit my config file to match the new experiment using the information below. 

Here's the human readable sample names
\```csv
sample_name condition shorthand
Sample1 .. ..
Sample2 .. .. 
Sample3 .. ..
\```

The new experiment has the following FASTQ files in ../data/my_experiment/:
\```sh
GS2436UQ5AF_R1_001.fastq.gz
...
\```

Here's the template config file you need to edit.
\```text
sample_name	experiment_replicate	selection_id	selection_replicate	technical_replicate	pair1	pair2
input	1	1	1	1	GS2436UQ5AF_R1_001.fastq.gz	GS2436UQ5AF_R2_001.fastq.gz
enriched	1	0		1	GS2431UQ5AF_R1_001.fastq.gz	GS2431UQ5AF_R2_001.fastq.gz
\```
```


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
