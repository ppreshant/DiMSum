#!/usr/bin/env bash

# This script duplicates a config file (both .txt and .params) in the config directory.
# USAGE: ./duplicate_config.sh <new_config_name> [source_config_name]

set -euo pipefail

config_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)"
source_name="${2:-theoAptzNNN_lokya}"
target_name="${1:-}"

if [[ -z "$target_name" || "$target_name" == */* || "$target_name" == *.* ]]; then
    echo "Usage: $0 <new_config_name> [source_config_name]" >&2
    echo "Example: $0 theoAptzepPCR_lokya theoAptzNNN_lokya" >&2
    exit 1
fi

for extension in txt params; do
    source_file="$config_dir/${source_name}.${extension}"
    target_file="$config_dir/${target_name}.${extension}"

    if [[ ! -f "$source_file" ]]; then
        echo "Source config not found: $source_file" >&2
        exit 1
    fi
    if [[ -e "$target_file" ]]; then
        echo "Target already exists: $target_file" >&2
        exit 1
    fi

done

cp "$config_dir/${source_name}.txt" "$config_dir/${target_name}.txt"
cp "$config_dir/${source_name}.params" "$config_dir/${target_name}.params"

printf 'Created %s.txt and %s.params in %s\n' "$target_name" "$target_name" "$config_dir"
