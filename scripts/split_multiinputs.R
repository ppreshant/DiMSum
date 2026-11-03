# Adhoc processing script.
# Lokya's multliple inputs containing della enriched dataset
# Author: Prashant K. ; 
# updated: 2/Nov/26

# open the full data; select a few columns of interest 
# pivot and nest ; save these as tsv files 
# go into a for loop to run post_process.R on each of these tsv files

# import libraries -------------
library(tidyverse)


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

# Nest each PCR series into a separate tibble, with the series name as a column
nested <- pivot_longer(data,
  cols = starts_with("PCR"),
  names_to = c("series", ".value"),
  names_pattern = "PCR([0-9])(.*)"
) |>
nest(.by = series)

# log
cat("\n--- nested data outline - - - - - \n") 
nested

# Calculate enrichment and leak scores for each nested tibble, and save the results as separate tsv files
# vectorized instead of a loop.
processed_nested <- pmap_dfr(nested,
  function(series, data) {
    # Calculate enrichment, leak, and WT-normalized scores for each nested tibble
    df <- data |>
      mutate(
        catalysis_score = Enriched_freq / Input_freq,
        leak_score = Unenriched_freq / Input_freq,
        relative_catalysis = catalysis_score / catalysis_score[Nham_nt == 0],
        relative_leak = leak_score / leak_score[Nham_nt == 0],
        net_catalysis = relative_catalysis / (1 + relative_leak)
      ) |>

      # Sort: WT first, then sort by top enrichment descending
      arrange(
        as_factor(Nham_nt == 0) |>
          fct_na_value_to_level("FALSE") |>
          desc(),
        desc(catalysis_score)
      )

    # Save the results as a separate csv file
    outfl <- str_c(base_dir, "processed_scores_v1_PCR", unique(series), ".csv")
    write_csv(df, outfl)

    # print(str_c("saved file: ", outfl)) # log
  }
)

# merge all the nested tibbles into a single tibble, with the series name fused back as the original data
merged <- unnest(processed_nested, cols = c(data)) |>

  pivot_wider(
    names_from = series,
    values_from = matches("_(count|freq|score)$"),
    names_glue = "PCR{series}_{.value}"
  )

write_csv(merged,
  str_c(base_dir, "processed_scores_v1_merged.csv")
)

# log
cat("\n--- merge column names - - - - - \n") 
colnames(merged)
