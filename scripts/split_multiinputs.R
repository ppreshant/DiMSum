# Adhoc processing script.
# Lokya's multliple inputs containing della enriched dataset
# Author: Prashant K. ; 
# updated: 2/Nov/26

# open the full data; select a few columns of interest 
# pivot and nest ; save these as tsv files 
# go into a for loop to run post_process.R on each of these tsv files

# import libraries -------------
library(tidyverse)

verbose_log <- FALSE

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
using_default_input <- length(args) < 1
if (using_default_input) {
  args <- c("della_enriched_library_lokya/DiMSum_Project/DiMSum_Project_variant_data_merge.tsv")
}
file_path <- args[[1]]

# Store post-processing outputs outside the DiMSum project directory. Resolve
# the input path first so that relative paths do not become rooted at `/`.
input_dir <- normalizePath(dirname(file_path), mustWork = TRUE)
base_dir <- normalizePath(file.path(input_dir, ".."), mustWork = TRUE)

# Redirect script output to a log file alongside the input TSV.
sink(file.path(base_dir, "post_processing.log"))
cat("Post-processing log for input file: ", file_path, "\n")
cat("date: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n\n")

# show the base_dir in log
cat("The base directory is:\n", base_dir, "\n")


# import data
data <- read_tsv(file_path, lazy = TRUE) |>
  select("nt_seq", "Nham_nt", ends_with("_count")) |>

  # Add columns
  mutate(sequence_length = str_length(nt_seq)) |> # sequence length
  mutate(across(
    ends_with("_count"),
    ~ .x / sum(.x, na.rm = TRUE),
    .names = "{.col}_freq"
  )) |>
  rename_with(
    ~ str_replace(.x, "_count_freq$", "_freq"),
    ends_with("_count_freq")
  ) |>

  # clean up names to only retain NAME_junk_.._.._count > name_count
  rename_with(
    ~ str_replace(.x, "^([^_]+).*_(count|freq)$", "\\1_\\2"),
    ends_with("_count") | ends_with("_freq")
  )

# Bring PCR series into a separate column (Group); calculate within each group and sort. 
# calcs: WT-normalized catalysis and leak scores, and net catalysis score.
series_long <- 
  pivot_longer(data,
  cols = starts_with("PCR"),
  names_to = c("series", ".value"),
  names_pattern = "PCR([0-9])(.*)"
  ) |> 

  # perform calculations within each series (due to grouping by)
  group_by(series) |>

  mutate(
    catalysis_score = Enriched_freq / Input_freq,
    leak_score = Unenriched_freq / Input_freq,
    relative_catalysis = catalysis_score / catalysis_score[Nham_nt == 0],
    relative_leak = leak_score / leak_score[Nham_nt == 0],
    net_catalysis = relative_catalysis / (1 + relative_leak)
  )

if (verbose_log) {
  # log
  cat("\n--- series_long data outline - - - - - \n") 
  series_long
}

# Save CSV files for each series, with the series name in the file name.

# Nest the series_long tibble by series, so that each series has its own tibble. For arranging before saving separate csv
nest(series_long) |> 

  # loop through the series_long df and save each tibble (df) as csv
  pmap_dfr(
    function(series, data) {

    # Sort: WT first, then sort by top enrichment descending
    sorted <- 
      arrange(data,
        as_factor(Nham_nt == 0) |>
          fct_na_value_to_level("FALSE") |>
          desc(),
        desc(catalysis_score)
      )

    # Save the results as a separate csv file
    output_file <- file.path(
      base_dir,
      str_c("processed_scores_v1_PCR", unique(series), ".csv")
    )
    write_csv(sorted, output_file)

    # log the saved file name
    cat("saved file: ", output_file, "\n")
  }
)

# merge all the series_long tibbles into a single tibble, with the series name fused back as the original data
merged <- series_long |>

  # merge series into column names, so that each series has its own set of columns
  pivot_wider(
    names_from = series,
    values_from = matches("_(count|freq|score)$"),
    names_glue = "PCR{series}_{.value}"
  )

# save a combined CSV file (for any extra analysis)
write_csv(merged,
  file.path(base_dir, "processed_scores_v1_merged.csv")
)

# log
cat("\n--- merge column names - - - - - \n") 
colnames(merged)
