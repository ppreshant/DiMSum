# post processing of the data to generate the final output files for Dylan
# Author: Prashant Kalvapalle,
# updated: 5/Oct/26

# Goals:
# 1. filter: Threshold >=2 counts in "Input" col;
# 2. Calculation: enrichment and leak scores;
# 3. Split: (?) Zeros in enriched counts columns into a separate file;
# 3b.            Madison: separate datasets for each temperature;

# Usage: Rscript post_process.R <path_to_input_file>
# Output: processed_data_full.csv, processed_concise.csv, post_processing.log (in the same dir as the input file)

# import libraries -------------
library(tidyverse)

# import data
args <- commandArgs(trailingOnly = TRUE)
using_default_input <- length(args) < 1
if (using_default_input) {
  args <- c("theoAptzNNN_lokya/variant_data_parsed.tsv")
}
file_path <- args[[1]]

# Redirect script output to a log file alongside the input TSV.
sink(file.path(dirname(file_path), "post_processing.log"))
cat("Post-processing log for input file: ", file_path, "\n")
cat("date: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "\n\n")

if (using_default_input) {
  cat("Usage: Rscript post_process.R <path_to_input_file>\n")
  cat("defaulting to `theoAptzNNN_lokya/variant_data_parsed.tsv`\n")
}

data <- read_tsv(file_path)


# Detecting key columns ------------------

## Regex patterns ---------------------
# Detect the columns for calculations: input, enrichment, leak
input_signature <- "Input"
enrich_signature <- "(neg25uM5fDUTheo|UraHisTheo)"
leak_signature <- "(NoTheo|UraTheo)"

type_suffix <- ".*_freq"

temp_signature <- "30|24|35"

# print the columns matching the regex patterns
input_col <- grep(str_c(input_signature, type_suffix),
                  colnames(data), value = TRUE)

enrich_col <- grep(str_c(enrich_signature, type_suffix),
                   colnames(data), value = TRUE)

leak_col <- grep(str_c(leak_signature, type_suffix),
                 colnames(data), value = TRUE)

# get input counts column name
input_counts_col <-
  grep(str_c(input_signature, ".*_count"),
       colnames(data), value = TRUE)

cat("column name matches\n")
list(
  "input_counts" = input_counts_col,
  "input" = input_col,
  "enrichment" = enrich_col,
  "leak" = leak_col
) %>%
  print()


## Error check -------

# throw an error if a single column is not found
if (any(lengths(list(input_counts_col, input_col, enrich_col, leak_col)) != 1)) {
  # give error as to which column was problematic and what it was
  # use a vectorized command or function to minimize repetition
  if (length(input_counts_col) != 1) {
    cat("Input counts column found: ", input_counts_col, "\n")
  }
  if (length(input_col) != 1) {
    cat("Input column found: ", input_col, "\n")
  }
  if (length(enrich_col) != 1) {
    cat("Enrichment column found: ", enrich_col, "\n")
  }
  if (length(leak_col) != 1) {
    cat("Leak column found: ", leak_col, "\n")
  }
  stop("Error: Required column not found or multiple columns found. Check log for details.")
}

# processing -----

# Threshold filter: for ease of calculations (denominator can't be zero)
# keep only rows where "Input" col >= 2 (filter out spurious zero/singletons)
filtered_data <- data |>
  filter(.data[[input_counts_col]] >= 2) |> # remove rows with Input count < 2
  select(-ends_with(c("_percent"))) # (x) percentage

# split the data into SNVs and indels and
# filter the indels more stringently for > 50 in Input count or enriched counts
snvs <- filtered_data |> filter(!is.na(Nham_nt))

indels <- filtered_data |>
  filter(is.na(Nham_nt)) |>
  filter(if_any(ends_with("count"), ~ . >= 50))

# combine the filtered SNVs and indels back into one dataset
filtered_indels_stringent <- bind_rows(snvs, indels)

cat("distribution of Nham_nt in the raw data :\n")
summarise(data, count = n(), .by = Nham_nt) |> print()

cat("\n\ndistribution of Nham_nt in the final filtered data :\n")
summarise(filtered_indels_stringent, count = n(), .by = Nham_nt) |> print()

# show how many rows were filtered out
cat("\n\nSummary --------------\n")
cat("Before filtering: ", nrow(data), " variants\n")
cat("After filtering: ", nrow(filtered_indels_stringent), " variants\n")
cat("filtered out: ", nrow(data) - nrow(filtered_indels_stringent), " variants")

cat("\n\nPost-processing complete.\n\n")

# Calculate enrichment and leak scores
processed_data <- filtered_indels_stringent %>%
  mutate(
    enrichment_score = .data[[enrich_col]] / .data[[input_col]],
    leak_score = .data[[leak_col]] / .data[[input_col]],
    .after = Nham_nt
  ) |> 

  # place Nham = 0 first, then arrange by enrichment score descending
  arrange(desc(Nham_nt == 0), desc(enrichment_score))
  

# Retain only key columns for Dylan's analysis
processed_concise <- processed_data |>
  select(nt_seq, enrichment_score, leak_score, Nham_nt, sequence_length)

# show the first few rows of the processed concise data
cat("\n\nFirst few rows of the processed concise data:\n")
head(processed_concise) |> print()

# write the processed datasets in the same dir as the input file
write.csv(processed_data,
          file = file.path(dirname(file_path), "processed_data.csv"),
          row.names = FALSE)
write.csv(processed_concise,
          file = file.path(dirname(file_path), "variant_enrichment_data.csv"),
          row.names = FALSE)
