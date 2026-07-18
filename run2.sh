#!/bin/bash
# TERMINAL 2  (host, AFTER run1.sh shows the mininet> prompt:  ./run2.sh)
# Loads the static table entries, then starts the starter capture.sh on the
# switch port to the Admin server (s1-eth5) so the DSCP-marked traffic is saved.
set -e

cid="$(docker ps -q --filter ancestor=p4-dataplane-hw | head -1)"
if [ -z "$cid" ]; then
  echo "No running p4-dataplane-hw container. Start ./run1.sh first."
  exit 1
fi

docker exec -it "$cid" bash -c '
  set -e
  simple_switch_CLI --thrift-port 9090 < src/s1-commands.txt
  echo
  echo "Tables loaded."
  echo ">>> Now go to TERMINAL 1 (mininet>) and run:  source /workspace/collect_evidence.txt"
  echo ">>> When the tests finish, press Ctrl+C here to stop the capture."
  echo
  mkdir -p /workspace/captures
  cd /workspace/captures
  exec ../starter/scripts/capture.sh s1-eth5 icmp     # writes capture-s1-eth5-<ts>.pcap here
'