#!/bin/bash
# TERMINAL 3  (host, AFTER you stopped the capture in run2.sh with Ctrl+C)
# Reads the newest non-empty s1-eth5 capture and shows the DSCP marking for each
# traffic class (only the h3->h5 direction, i.e. packets already marked by s1).
set -e

cid="$(docker ps -q --filter ancestor=p4-dataplane-hw | head -1)"
if [ -z "$cid" ]; then
  echo "No running p4-dataplane-hw container. Start ./run1.sh first."
  exit 1
fi

docker exec -it "$cid" bash -c '
  cd /workspace/captures 2>/dev/null || { echo "No captures/ folder. Run ./run2.sh + tests first."; exit 1; }
  pcap=""
  for f in $(ls -t *.pcap 2>/dev/null); do
    if [ -s "$f" ] && tcpdump -r "$f" -c 1 >/dev/null 2>&1; then pcap="$f"; break; fi
  done
  [ -z "$pcap" ] && { echo "No valid pcap found. Re-capture: ./run2.sh, run tests, THEN Ctrl+C."; exit 1; }
  echo "=== Reading $pcap  (only packets to h5 = already marked by the switch) ==="
  show() {
    echo
    echo ">>> $1"
    tcpdump -r "$pcap" -vv -n "$2" 2>/dev/null | grep --color=always -oE "tos 0x[0-9a-f]+, ttl [0-9]+, .*proto [A-Z]+" | head -4
  }
  show "ICMP        -> expect tos 0xb8 (DSCP 46, Interactive)"  "icmp and dst 10.0.4.50"
  show "TCP dst 80  -> expect tos 0x88 (DSCP 34, Web)"          "tcp and dst 10.0.4.50 and port 80"
  show "UDP dst 53  -> expect tos 0x68 (DSCP 26, UDP service)"  "udp and dst 10.0.4.50 and port 53"
  show "TCP dst 9999-> expect tos 0x0  (DSCP 0,  Other)"        "tcp and dst 10.0.4.50 and port 9999"
  echo
'