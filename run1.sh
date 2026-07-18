#!/bin/bash
# TERMINAL 1  (host, from repo root:  ./run1.sh)
# Uses the starter scripts: cleanup.sh -> compile.sh -> run_mininet.sh.
set -e

docker buildx build --platform linux/amd64 --load -t p4-dataplane-hw .

docker run --rm -it --platform linux/amd64 --privileged \
  -v "$PWD":/workspace -w /workspace p4-dataplane-hw bash -c '
    set -e
    starter/scripts/cleanup.sh || true          # clear any old mininet / switch state
    docker/verify-env.sh
    starter/scripts/compile.sh src/dataplane.p4 # -> src/dataplane.json
    echo
    echo ">>> Open a SECOND terminal and run ./run2.sh (loads tables + starts capture)"
    echo
    starter/scripts/run_mininet.sh src/dataplane.json   # opens mininet> and stays
  '