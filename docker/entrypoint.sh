#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "" ]]; then
  exec /bin/bash
fi

exec "$@"
