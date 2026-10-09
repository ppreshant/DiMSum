#!/bin/sh

# Usage:
#   ./scripts/collect_post_processing_files.sh [search_dir] [output_dir]
#
# Files are copied with their directory structure preserved under output_dir.

set -eu

## key variables ----------------------------------
scratch_dir="/scratch/alpine/$USER"
results_dir="${scratch_dir}/deepmut_variant_analysis/dimsum_results"
enrichment_data_dir="${results_dir}/enrichment_data"

search_dir=${1:-"$results_dir"}
output_dir=${2:-"$enrichment_data_dir"}

if [ ! -d "$search_dir" ]; then
    echo "Search directory not found: $search_dir" >&2
    exit 1
fi

mkdir -p "$output_dir"

find "$search_dir" \
    \( -type d \( -name archive -o -name della_pilot_ez \) -prune \) \
    -o -type f \( \
        -name 'processed_data*.csv' \
        -o -name 'variant_enrichment_data*.csv' \
        -o -name 'post_processing.log' \
    \) -exec sh -c '
        output_dir=$1
        search_dir=$2
        shift 2

        for file do
            relative_file=${file#"$search_dir"/}
            destination_dir="$output_dir/$(dirname "$relative_file")"

            mkdir -p "$destination_dir"
            cp "$file" "$destination_dir/"
            echo "Copied: $file -> $destination_dir/"
        done
    ' sh "$output_dir" "$search_dir" {} +

echo "Finished copying matching files into $output_dir"
