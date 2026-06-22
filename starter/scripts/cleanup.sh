#!/usr/bin/env bash
set -euo pipefail

sudo mn -c
sudo pkill -f simple_switch || true
echo "Mininet cleanup completed."
