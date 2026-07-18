# CN HW3 — P4 Data Plane (BMv2 / Mininet)

A programmable edge switch `s1` written in P4-16 for the BMv2 `simple_switch`
target. It parses packets, forwards IPv4 by longest-prefix match, classifies
traffic, marks DSCP for QoS, and enforces a security policy — entirely in the
data plane. No routing protocol or dynamic control-plane algorithm is used; the
match-action tables are filled with static entries loaded over the Thrift CLI.

## Files
```
src/dataplane.p4       # the P4-16 program (v1model / simple_switch)
src/s1-commands.txt    # static table entries (simple_switch_CLI format)
run1.sh                # TERMINAL 1: cleanup -> compile -> Mininet CLI
run2.sh                # TERMINAL 2: load tables -> capture.sh (pcap)
collect_evidence.txt   # Mininet source file: host routing + the 8 tests
src/README.md          # this file
```

## Host vs. container
Everything (p4c, mininet, simple_switch, tcpdump) lives inside the Docker
container; your host only runs `docker` commands. `run1.sh` / `run2.sh` are host
launchers that pass the work into the container, so you never have to paste
commands one by one.

## Fast path (three steps, two terminals)

**Terminal 1** — build + compile + start Mininet (uses the starter scripts
`cleanup.sh`, `compile.sh`, `run_mininet.sh`):
```bash
./run1.sh
```
Leave it at the `mininet>` prompt.

**Terminal 2** — load the static tables and start the packet capture (uses
`capture.sh` on `s1-eth5`, the port toward the Admin server):
```bash
./run2.sh
```

**Back in Terminal 1** — run host routing + all tests, saving the log:
```
mininet> source /workspace/collect_evidence.txt
```
When the tests finish, press **Ctrl+C in Terminal 2** to stop the capture. The
pcap is written to `captures/capture-s1-eth5-<timestamp>.pcap`.

## Why the routing setup is needed
The starter `topology.py` runs `ip route flush root 0/0` on each host and then
tries to add a default route via the gateway. The flush also removes the host's
connected subnet route, so the default-route add fails ("Nexthop has invalid
gateway") and every ping reports "Network is unreachable". `collect_evidence.txt`
fixes this per host with one line:
```
ip route replace default via 10.0.X.1 dev hX-eth0 onlink
```
`onlink` tells the kernel to treat the gateway as directly reachable, so the
default route installs without a connected route. The gateway ARP (a single
gateway MAC `00:aa:bb:00:00:01`) is already set by the topology, so packets then
reach `s1`, which routes them in the data plane and rewrites the destination MAC
to the real host MAC.

## Topology (from starter/topology/topology.py)
| Host | Role | IP | Port | MAC |
| --- | --- | --- | --- | --- |
| h1 | Student | 10.0.1.10 | 1 | 00:00:00:00:01:10 |
| h2 | Student | 10.0.1.20 | 2 | 00:00:00:00:01:20 |
| h3 | Staff | 10.0.2.30 | 3 | 00:00:00:00:02:30 |
| h4 | Research | 10.0.3.40 | 4 | 00:00:00:00:03:40 |
| h5 | Admin server | 10.0.4.50 | 5 | 00:00:00:00:04:50 |
| h6 | External | 10.0.5.60 | 6 | 00:00:00:00:05:60 |

## What the tests check (all run by collect_evidence.txt)
```
h3 -> h5   Staff -> Admin       : success (ttl becomes 63, i.e. TTL decremented)
h4 -> h6   Research -> External : success
h1 -> h2   Student <-> Student  : success
h1 -> h5   Student -> Admin     : 100% loss (blocked by firewall)
h6 -> h5   External -> Admin    : 100% loss (extra policy)
h3 -> h5   TTL=1                : 100% loss (expired at switch)
h3 -> 10.0.9.99  unknown dest   : 100% loss (default_action drop)
```
Results are saved to `evidence/terminal-outputs.txt`.

## DSCP evidence
The capture on `s1-eth5` shows the marking. Read it back with:
```bash
tcpdump -r captures/capture-s1-eth5-<timestamp>.pcap -vv -n icmp | grep -i tos
```
ICMP (Interactive) shows `tos 0xb8` = DSCP 46. The same lines show `ttl 63` on
requests leaving the switch, which also proves the TTL decrement.

DSCP map: Interactive (ICMP, TCP/22) = 46 (0xb8), Web (TCP 80/443) = 34 (0x88),
UDP service = 26 (0x68), Other = 0.

## Pipeline (order of tables)
```
parse -> sec_policy(ternary) -> classify(ternary) -> qos_mark(exact)
      -> TTL check -> ipv4_lpm(LPM: forward + MAC rewrite + TTL--)
      -> deparse + IPv4 checksum recompute
```
Firewall runs first so forbidden packets are dropped before any forwarding or
marking work. The classification result travels to the QoS stage through
`meta.class_id`. Full design discussion is in `report.pdf`.

## Match-kind choices
- `sec_policy` : ternary — wildcards on src/dst prefixes.
- `classify`   : ternary — (protocol, port) with don't-cares.
- `qos_mark`   : exact   — class_id is a small exact key.
- `ipv4_lpm`   : LPM     — longest-prefix forwarding on dst IPv4.

## Other starter helpers
- `starter/scripts/cleanup.sh` — `mn -c` + kill simple_switch (run between runs).
- `starter/scripts/capture.sh <iface> <filter>` — the capture used by run2.sh.

## Notes / limitations
- Tables are static (no dynamic control plane), as required.
- IPv6 is not handled; only IPv4 is parsed and forwarded.
- BMv2 is a functional model, not a performance benchmark.
- The switch does not answer ARP; hosts reach it via a default route to the
  gateway with a static gateway ARP (see the routing note above).

---
Based on the CN HW3 P4 Data Plane starter by Parmis Hemasian, licensed under the
Apache License 2.0. This README has been rewritten and modified for this
submission.