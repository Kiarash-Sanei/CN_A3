#!/bin/bash
# TERMINAL 2  (run this on your HOST AFTER run1.sh shows the `mininet>` prompt)
#
# It finds the running container automatically (no manual id needed), loads the
# static table entries into s1, then leaves you at a shell inside the container.
# Do the ping / tcpdump tests back in TERMINAL 1 at the `mininet>` prompt.
set -e

cid="$(docker ps -q --filter ancestor=p4-dataplane-hw | head -1)"
if [ -z "$cid" ]; then
  echo "No running p4-dataplane-hw container found. Start ./run1.sh first."
  exit 1
fi

docker exec -it "$cid" bash -c '
  simple_switch_CLI --thrift-port 9090 < src/s1-commands.txt
  echo
  exec bash
'