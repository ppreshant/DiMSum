#!/usr/bin/env python3

# Author: Copilot AI, 15/Sep/26 w Prashant Kalvapalle

import argparse
import csv
import re
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description="Select variant columns and add count frequencies and percentages."
    )
    parser.add_argument("input", type=Path, help="DiMSum *_variant_data_merge.tsv file")
    parser.add_argument(
        "output",
        type=Path,
        nargs="?",
        help="Output TSV path (default: input name with _user.tsv suffix)",
    )
    return parser.parse_args()


def read_header(input_path):
    with input_path.open(newline="") as input_file:
        reader = csv.reader(input_file, delimiter="\t")
        try:
            header = next(reader)
        except StopIteration as error:
            raise ValueError(f"Input file is empty: {input_path}") from error
    return header


def count_totals(input_path, count_columns):
    totals = {column: 0 for column in count_columns}
    with input_path.open(newline="") as input_file:
        reader = csv.DictReader(input_file, delimiter="\t")
        for row_number, row in enumerate(reader, start=2):
            for column in count_columns:
                value = row[column]
                if value == "":
                    value = "0"
                try:
                    totals[column] += int(value)
                except ValueError as error:
                    raise ValueError(
                        f"Invalid integer in {input_path}, row {row_number}, "
                        f"column {column}: {value!r}"
                    ) from error
    return totals


def format_number(value):
    return f"{value:.12g}"


def write_output(
    input_path,
    output_path,
    selected_columns,
    count_columns,
    input_frequency_columns,
    totals,
):
    identifier_columns = [column for column in selected_columns if column not in count_columns]
    percent_columns = [column[:-6] + "_percent" for column in count_columns]
    frequency_columns = [column[:-6] + "_freq" for column in count_columns]
    output_columns = [
        *identifier_columns,
        *percent_columns,
        *frequency_columns,
        *count_columns,
        "sequence_length",
    ]

    output_rows = []
    with input_path.open(newline="") as input_file:
        reader = csv.DictReader(input_file, delimiter="\t")
        for row in reader:
            output_row = {}
            for column in selected_columns:
                output_row[column] = row[column]
                if column in count_columns:
                    count = int(row[column] or 0)
                    total = totals[column]
                    frequency = count / total if total else 0.0
                    output_row[column[:-6] + "_freq"] = format_number(frequency)
                    output_row[column[:-6] + "_percent"] = format_number(
                        frequency * 100
                    )
            output_row["sequence_length"] = str(len(row["nt_seq"]))
            output_rows.append(output_row)

    output_rows.sort(
        key=lambda row: tuple(
            float(row[column]) for column in input_frequency_columns
        ),
        reverse=True,
    )
    with output_path.open("w", newline="") as output_file:
        writer = csv.DictWriter(output_file, fieldnames=output_columns, delimiter="\t")
        writer.writeheader()
        writer.writerows(output_rows)


def main():
    args = parse_args()
    input_path = args.input
    output_path = args.output or input_path.with_name(
        input_path.name.removesuffix(".tsv") + "_user.tsv"
    )

    header = read_header(input_path)
    required_columns = ["nt_seq", "Nham_nt"]
    count_columns = [column for column in header if column.endswith("_count")]
    missing_columns = [column for column in required_columns if column not in header]
    if missing_columns:
        raise ValueError(f"Missing required columns: {', '.join(missing_columns)}")
    if not count_columns:
        raise ValueError("No columns ending in '_count' were found")

    selected_columns = ["nt_seq", "Nham_nt", *count_columns]
    input_frequency_columns = [
        column[:-6] + "_freq"
        for column in count_columns
        if re.search(r"input", column, re.IGNORECASE)
    ]
    if not input_frequency_columns:
        raise ValueError("No columns containing 'input' and ending in '_count' were found")
    input_frequency_columns = input_frequency_columns[:1]

    totals = count_totals(input_path, count_columns)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    write_output(
        input_path,
        output_path,
        selected_columns,
        count_columns,
        input_frequency_columns,
        totals,
    )
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()