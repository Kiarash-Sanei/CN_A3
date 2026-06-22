#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 path/to/program.json" >&2
  exit 2
fi

json_file="$1"

if [[ ! -f "$json_file" ]]; then
  echo "BMv2 JSON file not found: $json_file" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
topology="$script_dir/../topology/topology.py"

sudo python3 "$topology" --json "$json_file"
