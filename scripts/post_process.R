# post processing of the data to generate the final output files for Dylan
# Author: Prashant Kalvapalle,
# Updated on: 8/Oct/26

# Goals:
# 1. filter: Threshold >=2 counts in "Input" col;
# 2. Calculation: enrichment and leak scores;
# 3. Split: (?) Zeros in enriched counts columns into a separate file;
# 3b.            Madison: separate datasets for each temperature;

# Usage: Rscript post_process.R <path_to_input_file>
# Output: processed_data.csv, variant_enrichment_data.csv, post_processing.log
# (or temperature-suffixed CSVs in multi-temperature mode)

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

multiple_temp_mode <- FALSE # default to single temperature mode

## Regex patterns ---------------------
# Detect the columns for calculations: input, enrichment, leak
input_signature <- "Input"
enrich_signature <- "(neg25uM5fDUTheo|UraHisTheo)"
leak_signature <- "(NoTheo|UraHisVeh)"
theo_effect_signature <- "UraTheo"

type_suffix <- ".*_freq"

temp_signature <- "(Theo|Veh)[0-9]{2}(C|_)"
extract_temperature <- function(columns) {
  str_extract(columns, temp_signature) |>
    str_extract("[0-9]{2}(C|_)") |>
    str_replace("_$", "C")
}

# print the columns matching the regex patterns
input_col <- grep(str_c(input_signature, type_suffix),
                  colnames(data), value = TRUE)

enrich_col <- grep(str_c(enrich_signature, type_suffix),
                   colnames(data), value = TRUE)

leak_col <- grep(
  str_c(leak_signature, type_suffix),
  colnames(data),
  value = TRUE
)

theo_effect_col <- grep(
  str_c(theo_effect_signature, type_suffix),
  colnames(data),
  value = TRUE
)

# get input counts column name
input_counts_col <-
  grep(str_c(input_signature, ".*_count"),
       colnames(data), value = TRUE)

cat("\nDetected columns -------------------------\n\n")

detected_columns <-
  list(
    "input_counts" = input_counts_col,
    "input" = input_col,
    "enrichment" = enrich_col,
    "leak" = leak_col
  ) |> print()


# Temperature processing (Madison data) ----------------

# look for temperature signatures in the column names
temp_cols <- grep(temp_signature, colnames(data), value = TRUE)
temperatures_detected <- extract_temperature(temp_cols) |> unique()

enrichment_table <- tibble(
  temperature = extract_temperature(enrich_col),
  enrichment = enrich_col
)

leak_table <- tibble(
  temperature = extract_temperature(leak_col),
  leak = leak_col
)

theo_effect_table <- tibble(
  temperature = extract_temperature(theo_effect_col),
  theo_effect = theo_effect_col
)

temp_table <- enrichment_table |>
  left_join(leak_table, by = "temperature") |>
  left_join(theo_effect_table, by = "temperature")


## Error checks -------

# Temperature to key columns mapping table
if (length(temp_cols) > 0) {
  cat("\n\nTable of detected temperatures and their columns:\n")
  print(temp_table)

  if (anyNA(temp_table$temperature) ||
      anyDuplicated(temp_table$temperature)) {
    stop(
      "Enrichment columns must have one unique temperature each. ",
      "Check the detected column names."
    )
  }

  if (any(!is.na(temp_table$leak) &
          !temp_table$temperature %in% extract_temperature(leak_col))) {
    stop(
      "Leak columns contain temperatures without matching enrichment columns. ",
      "Check the detected column names."
    )
  }

  if (any(!is.na(temp_table$theo_effect) &
          !temp_table$temperature %in% extract_temperature(theo_effect_col))) {
    stop(
      "Theo-effect columns contain temperatures without matching enrichment columns. ",
      "Check the detected column names."
    )
  }

  missing_leak <- is.na(temp_table$leak)
  if (any(missing_leak)) {
    warning(
      "No leak column found for: ",
      paste(temp_table$temperature[missing_leak], collapse = ", "),
      ". Leak scores will be omitted for those temperatures."
    )
  }

}


# Required columns must be unambiguous; leak and Theo-effect may be
# absent for individual temperatures.
if (length(input_counts_col) != 1 ||
    length(input_col) != 1 ||
    length(enrich_col) == 0) {
  stop(
    "Input, input-count, and enrichment columns must be present and unambiguous.",
    " Check the detected columns."
  )
}

if (length(temp_cols) > 0) {
  multiple_temp_mode <- length(enrich_col) > 1
  cat("\n\nData will be split by temperatures for calculations and output: ",
      paste(temperatures_detected, collapse = ", "), "\n")
} else if (length(leak_col) != 1 || length(enrich_col) != 1) {
  stop(
    "Single-temperature input requires exactly one enrichment and leak column.",
    " Check the detected columns."
  )
}

# No temperature signatures: default mode (Lokya data)
if (!multiple_temp_mode) {
  temp_table <- tibble(
    temperature = NA_character_,
    enrichment = enrich_col,
    leak = leak_col,
    theo_effect = NA_character_
  )
}


# Processing ------------------
## filtering --------------

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

cat("\n\nFiltering checks ----------------\n\n")

cat("distribution of Nham_nt in the raw data :\n")
summarise(data, count = n(), .by = Nham_nt) |> print()

cat("\n\ndistribution of Nham_nt in the final filtered data :\n")
summarise(filtered_indels_stringent, count = n(), .by = Nham_nt) |> print()

# show how many rows were filtered out
cat("\n\nSummary --------------\n\n")
cat("Before filtering: ", nrow(data), " variants\n")
cat("After filtering: ", nrow(filtered_indels_stringent), " variants\n")
cat("filtered out: ", nrow(data) - nrow(filtered_indels_stringent), " variants")

cat("\n\nFiltering complete. Calculating enrichment and leak scores.\n")

## calculation and output ------------------------

column_scorer <- function(numerator, score_name, suffix) {
  if (is.na(numerator) || !numerator %in% names(filtered_indels_stringent)) {
    return(NULL)
  }

  score <- filtered_indels_stringent[[numerator]] /
    filtered_indels_stringent[[input_col]]

  tibble(!!paste0(score_name, suffix) := score)
}

scored_columns <- map(seq_len(nrow(temp_table)), function(row) {
  temperature <- temp_table$temperature[[row]]
  suffix <- if (is.na(temperature)) "" else paste0("_", temperature)

  list(
    column_scorer(temp_table$enrichment[[row]], "enrichment_score", suffix),
    column_scorer(temp_table$leak[[row]], "leak_score", suffix),
    column_scorer(temp_table$theo_effect[[row]], "theo_effect_score", suffix)
  ) |>
    compact() |>
    list_cbind()
}) |>
  list_cbind()

processed_data <- bind_cols(filtered_indels_stringent, scored_columns) |>
  # place Nham = 0 first, then arrange by the first enrichment score descending
  arrange(
    as_factor(Nham_nt == 0) |>
      fct_na_value_to_level("FALSE") |>
      desc(),
    desc(.data[[names(scored_columns)[[1]]]])
  )

write.csv(
  processed_data,
  file = file.path(dirname(file_path), "processed_data.csv"),
  row.names = FALSE
)

for (row in seq_len(nrow(temp_table))) {
  temperature <- temp_table$temperature[[row]]
  suffix <- if (is.na(temperature)) "" else paste0("_", temperature)
  enrichment_score_col <- paste0("enrichment_score", suffix)
  leak_score_col <- paste0("leak_score", suffix)
  theo_effect_score_col <- paste0("theo_effect_score", suffix)

  processed_concise <- processed_data |>
    select(
      nt_seq,
      any_of(enrichment_score_col),
      any_of(leak_score_col),
      any_of(theo_effect_score_col),
      Nham_nt,
      sequence_length
    ) |>
    rename(
      enrichment_score = any_of(enrichment_score_col),
      leak_score = any_of(leak_score_col),
      theo_effect_score = any_of(theo_effect_score_col)
    ) |>

    # rearrange within each temp Nham = 0 first, then enrichment score desc
    arrange(
      as_factor(Nham_nt == 0) |>
        fct_na_value_to_level("FALSE") |>
        desc(),
      desc(enrichment_score)
    )

  cat("\n\nFirst few rows of the processed concise data", suffix, ":\n")
  head(processed_concise) |> print()

  write.csv(
    processed_concise,
    file = file.path(
      dirname(file_path),
      paste0("variant_enrichment_data", suffix, ".csv")
    ),
    row.names = FALSE
  )

  # message about files written
  cat("\n\nProcessed concise data written to: ",
      file.path(
        dirname(file_path),
        paste0("variant_enrichment_data", suffix, ".csv")
      ), "\n")
}

cat("\n\nComplete! Processed data written to: ",
    file.path(dirname(file_path), "processed_data.csv"), "\n")

cat("\n\nPost-processing complete.\n\n")
