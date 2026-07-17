#!/bin/bash
# TERMINAL 1  (run this on your HOST, from the repo root:  ./run1.sh)
#
# Why the old command list failed as a script: `docker run -it` opens an
# INTERACTIVE shell and blocks, so the lines after it never ran inside the
# container. Here we pass the setup commands INTO the container, so they run in
# order and then Mininet's interactive prompt stays open at the end.
set -e

# Build once (cached afterwards, so this is fast on later runs).
# docker buildx build --platform linux/amd64 --load -t p4-dataplane-hw .

# One container session: verify tools -> compile P4 -> open the Mininet CLI.
docker run --rm -it --platform linux/amd64 --privileged \
  -v "$PWD":/workspace -w /workspace p4-dataplane-hw bash -c '
    set -e
    docker/verify-env.sh
    starter/scripts/compile.sh src/dataplane.p4
    echo
    echo ">>> Now open a SECOND terminal and run:  ./run2.sh   (to load the tables)"
    echo
    starter/scripts/run_mininet.sh src/dataplane.json
  '