#!/usr/bin/env bash
set -euo pipefail

missing=0

check_command() {
  local name="$1"
  shift

  if ! command -v "$name" >/dev/null 2>&1; then
    echo "MISSING: $name"
    missing=1
    return
  fi

  echo "OK: $name"
  "$@" || {
    echo "FAILED: $*"
    missing=1
  }
}

check_command p4c p4c --version
check_command simple_switch simple_switch --version
check_command simple_switch_CLI simple_switch_CLI --help
check_command mn mn --version
check_command python3 python3 --version
check_command tcpdump tcpdump --version
check_command tshark tshark --version
check_command ip ip -V
check_command ping ping -V
check_command ifconfig ifconfig --version
check_command git git --version
check_command make make --version

python3 - <<'PY'
import scapy
print("OK: scapy", scapy.__version__)
PY

if [[ "$missing" -ne 0 ]]; then
  echo "One or more required tools are missing or not runnable."
  exit 1
fi

echo "Environment verification passed."
