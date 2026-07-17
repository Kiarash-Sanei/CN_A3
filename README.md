# CN HW3 — P4 Data Plane (BMv2 / Mininet)

A programmable edge switch `s1` written in P4-16 for the BMv2 `simple_switch`
target. It parses packets, forwards IPv4 by longest-prefix match, classifies
traffic, marks DSCP for QoS, and enforces a security policy — entirely in the
data plane. No routing protocol or dynamic control-plane algorithm is used; the
match-action tables are filled with static entries loaded over the Thrift CLI.

## Files
```
src/dataplane.p4     # the P4-16 program (v1model / simple_switch)
src/s1-commands.txt  # static table entries (simple_switch_CLI format)
run1.sh              # TERMINAL 1 launcher (build + compile + Mininet CLI)
run2.sh              # TERMINAL 2 launcher (load the tables)
src/README.md        # this file
```

## Host vs. container — read this first
Everything (p4c, mininet, simple_switch, tcpdump) lives **inside the Docker
container**, not on your host. Your host only runs `docker` commands.

**Why the old "just paste the whole file" approach failed:** a line like
`docker run -it ...` opens an *interactive* shell and blocks; any lines written
after it never run inside the container (they run on the host later, where p4c
and mininet do not exist, so they error). `run_mininet.sh` is interactive too —
it opens the `mininet>` prompt and stays there. That is exactly why the commands
had to be pasted one by one. The two scripts below fix that by passing the setup
commands *into* the container.

## Fast path (two terminals)

**Terminal 1** — on your host, from the repo root:
```bash
./run1.sh
```
This builds the image (cached after the first time), then inside one container
session: verifies tools, compiles `src/dataplane.p4` to `src/dataplane.json`,
and opens the `mininet>` prompt (leave it open).

**Terminal 2** — on your host, after `mininet>` appears:
```bash
./run2.sh
```
This attaches to the same container and loads `src/s1-commands.txt` into s1.
For a clean load with no `DUPLICATE_ENTRY` lines, load the tables only once per
Mininet session (restart Terminal 1 if you need to reload).

Then run the tests **back in Terminal 1**, at the `mininet>` prompt (below).

## Manual path (if you prefer to type each step)
```bash
# host:
docker buildx build --platform linux/amd64 --load -t p4-dataplane-hw .
docker run --rm -it --platform linux/amd64 --privileged -v "$PWD":/workspace p4-dataplane-hw
# now INSIDE the container:
cd /workspace
docker/verify-env.sh
starter/scripts/compile.sh src/dataplane.p4
starter/scripts/run_mininet.sh src/dataplane.json      # stays at mininet>
# second host terminal, attach to the SAME container:
docker exec -it "$(docker ps -q --filter ancestor=p4-dataplane-hw | head -1)" bash
cd /workspace && simple_switch_CLI --thrift-port 9090 < src/s1-commands.txt
```

## Topology model
`starter/topology/topology.py` makes `s1` a pure L3 router: each host has a
default route via its gateway `10.0.X.1`, with a static ARP mapping that gateway
to a single gateway MAC `00:aa:bb:00:00:01`. Inter-subnet packets reach `s1`
with `eth.dst = 00:aa:bb:00:00:01`; `ipv4_forward` rewrites `eth.dst` to the
destination host's real MAC and decrements the TTL.

| Host | Role | IP | Port | MAC |
| --- | --- | --- | --- | --- |
| h1 | Student | 10.0.1.10 | 1 | 00:00:00:00:01:10 |
| h2 | Student | 10.0.1.20 | 2 | 00:00:00:00:01:20 |
| h3 | Staff | 10.0.2.30 | 3 | 00:00:00:00:02:30 |
| h4 | Research | 10.0.3.40 | 4 | 00:00:00:00:03:40 |
| h5 | Admin server | 10.0.4.50 | 5 | 00:00:00:00:04:50 |
| h6 | External | 10.0.5.60 | 6 | 00:00:00:00:05:60 |

## Tests (type these at the `mininet>` prompt in Terminal 1)
```
h3 ping -c3 h5          # Staff  -> Admin    : success
h4 ping -c3 h6          # Research-> External: success
h1 ping -c3 h5          # Student -> Admin   : 100% loss (blocked)
h6 ping -c3 h5          # External-> Admin   : 100% loss (extra policy)
h3 ping -c2 -t 1 h5     # TTL=1 -> expired at switch -> 100% loss
h3 ping -c2 10.0.9.99   # unknown dest -> default drop -> 100% loss
```
Student <-> student (same subnet, so add a peer ARP entry first):
```
h1 ip neigh add 10.0.1.20 lladdr 00:00:00:00:01:20 dev h1-eth0 nud permanent
h2 ip neigh add 10.0.1.10 lladdr 00:00:00:00:01:10 dev h2-eth0 nud permanent
h1 ping -c3 h2          # success
```
DSCP marking (look for `tos 0xb8` = DSCP 46):
```
h5 tcpdump -i h5-eth0 -vv -n icmp &
h3 ping -c2 h5
```

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

## Notes / limitations
- Tables are static (no dynamic control plane), as required.
- IPv6 is not handled; only IPv4 is parsed and forwarded.
- BMv2 is a functional model, not a performance benchmark.
- The switch does not answer ARP; the intra-subnet test needs the one-line peer
  ARP entry shown above.

---
Based on the CN HW3 P4 Data Plane starter by Parmis Hemasian, licensed under the
Apache License 2.0. This README has been rewritten and modified for this
submission.