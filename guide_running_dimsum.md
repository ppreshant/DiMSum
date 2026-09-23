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

