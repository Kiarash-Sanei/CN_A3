#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
p4_file="$repo_root/starter/p4/warmup_example.p4"
json_file="$repo_root/starter/p4/warmup_example.json"

"$script_dir/compile.sh" "$p4_file"

echo "Starting topology briefly. This does not validate the homework solution."
sudo python3 "$repo_root/starter/topology/topology.py" --json "$json_file" --no-cli

echo "Smoke test passed."
