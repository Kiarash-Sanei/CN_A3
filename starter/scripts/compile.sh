#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 path/to/program.p4" >&2
  exit 2
fi

p4_file="$1"

if [[ ! -f "$p4_file" ]]; then
  echo "P4 file not found: $p4_file" >&2
  exit 1
fi

out_file="${p4_file%.p4}.json"

echo "Compiling $p4_file -> $out_file"

if [[ -d "$out_file" ]]; then
  rm -rf "$out_file"
fi

if command -v p4c-bm2-ss >/dev/null 2>&1; then
  compiler=(p4c-bm2-ss --std p4-16 -o "$out_file" "$p4_file")
else
  build_dir="${p4_file%.p4}.build"
  rm -rf "$build_dir"
  compiler=(p4c --target bmv2 --arch v1model --std p4-16 -o "$build_dir" "$p4_file")
fi

if ! "${compiler[@]}"; then
  echo "P4 compilation failed. Read the compiler error above and fix the P4 program." >&2
  exit 1
fi

if [[ ! -f "$out_file" ]]; then
  generated_json="$(find "${p4_file%.p4}.build" -maxdepth 1 -name '*.json' -type f 2>/dev/null | head -n 1 || true)"
  if [[ -z "$generated_json" ]]; then
    echo "Compilation finished, but no BMv2 JSON output was found." >&2
    exit 1
  fi
  cp "$generated_json" "$out_file"
fi

echo "Compilation succeeded: $out_file"
