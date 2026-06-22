#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 interface [tcpdump-filter]" >&2
  echo "Example: $0 h1-eth0 \"ip\"" >&2
  exit 2
fi

interface="$1"
filter="${2:-ip}"
timestamp="$(date +%Y%m%d-%H%M%S)"
outfile="capture-${interface}-${timestamp}.pcap"

echo "Capturing on $interface with filter: $filter"
echo "Output: $outfile"
echo "Press Ctrl+C to stop."

sudo tcpdump -i "$interface" -vv -w "$outfile" "$filter"
