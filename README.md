# CN HW3 — P4 Data Plane (BMv2 / Mininet)

A programmable edge switch `s1` implemented in P4-16 for the BMv2
`simple_switch` target. It routes IPv4 by longest-prefix match, classifies
traffic, marks DSCP for QoS, and enforces a security policy — entirely in the
data plane. No routing protocol or dynamic control-plane algorithm is used; the
match-action tables are populated with static entries loaded over the BMv2
Thrift CLI.

## Files
```
src/dataplane.p4     # the P4-16 program (v1model / simple_switch)
src/s1-commands.txt  # static table entries (simple_switch_CLI format)
src/README.md        # this file
```

## Pipeline design
Ingress processing runs four match-action stages in this order:
```
parse (Eth, IPv4, TCP/UDP/ICMP)
  -> sec_policy (ternary firewall)
  -> classify   (ternary; result stored in meta.class_id)
  -> qos_mark   (exact class_id -> DSCP)
  -> TTL check  (drop expired packets)
  -> ipv4_lpm   (LPM: forward + MAC rewrite + TTL--)
  -> deparse + IPv4 checksum recompute
```
The firewall runs first so forbidden packets are dropped before any expensive
forwarding, marking, or checksum work. Classification happens before QoS so the
DSCP value can be derived from the traffic class carried in `meta.class_id`.

| Table | Match kind | Purpose | Key actions |
| --- | --- | --- | --- |
| `sec_policy` | ternary | firewall (wildcards on src/dst prefixes) | `drop_pkt`, `allow` |
| `classify` | ternary | traffic class from (protocol, L4 port) | `set_class` |
| `qos_mark` | exact | class → DSCP | `set_dscp` |
| `ipv4_lpm` | LPM | forward on dst IPv4 | `ipv4_forward`, `drop_pkt` |

## Traffic classes and DSCP
| Class | Match | DSCP | tcpdump ToS |
| --- | --- | --- | --- |
| Interactive | ICMP, TCP/22 (SSH) | 46 (EF) | `tos 0xb8` |
| Web | TCP/80, TCP/443 | 34 (AF41) | `tos 0x88` |
| UDP service | any UDP | 26 (AF31) | `tos 0x68` |
| Other / Bulk | everything else (default) | 0 (BE) | `tos 0x0` |

## Security policy (in the data plane)
- Students (`10.0.1.0/24`) **cannot** reach the Admin subnet (`10.0.4.0/24`).
- Staff (`10.0.2.0/24`) **can** reach the Admin subnet (allowed by default).
- Research (`10.0.3.0/24`) **can** reach the external host.
- Student ↔ student traffic is allowed.
- **Extra policy:** the external host (`10.0.5.0/24`) **cannot** reach the Admin
  subnet, protecting the sensitive server from the outside.

The two drop rules are non-overlapping, so their ternary priority values do not
conflict; anything not matched falls through to `default_action = allow`.

## Topology model (important)
The provided `starter/topology/topology.py` makes `s1` a pure **L3 router**:
each host has a default route via its gateway `10.0.X.1`, and a static ARP entry
mapping that gateway to a single gateway MAC `00:aa:bb:00:00:01`. Inter-subnet
packets therefore reach `s1` with `eth.dst = 00:aa:bb:00:00:01`; `ipv4_forward`
rewrites `eth.dst` to the destination host's real MAC, moves the old dst into
`eth.src`, and decrements the TTL.

Host / port / MAC map (from `topology.py`):

| Host | Role | IP | Port | MAC |
| --- | --- | --- | --- | --- |
| h1 | Student | 10.0.1.10 | 1 | 00:00:00:00:01:10 |
| h2 | Student | 10.0.1.20 | 2 | 00:00:00:00:01:20 |
| h3 | Staff | 10.0.2.30 | 3 | 00:00:00:00:02:30 |
| h4 | Research | 10.0.3.40 | 4 | 00:00:00:00:03:40 |
| h5 | Admin server | 10.0.4.50 | 5 | 00:00:00:00:04:50 |
| h6 | External | 10.0.5.60 | 6 | 00:00:00:00:05:60 |

## 0. Build the image and start the container
From the repository root:
```bash
docker buildx build --platform linux/amd64 --load -t p4-dataplane-hw .
docker run --rm -it --platform linux/amd64 --privileged -v "$PWD":/workspace p4-dataplane-hw
docker/verify-env.sh      # expect: "Environment verification passed."
```

## 1. Compile the P4 program
```bash
starter/scripts/compile.sh src/dataplane.p4
# expect: "Compilation succeeded: src/dataplane.json"
```

## 2. Start the topology (switch s1 + 6 hosts)
```bash
starter/scripts/run_mininet.sh src/dataplane.json
```
This prints the BMv2 thrift port (`9090`) and drops you into `mininet>`.

## 3. Load the static table entries into s1
In a **second terminal** inside the same container:
```bash
simple_switch_CLI --thrift-port 9090 < src/s1-commands.txt
```
Confirm the port/MAC map once with `mininet> net`.

## 4. Tests and evidence

### 4.1 Forwarding — allowed inter-subnet flows should succeed
```
mininet> h3 ping -c3 h5     # Staff   -> Admin : PASS
mininet> h4 ping -c3 h6     # Research-> Ext   : PASS
```

### 4.2 Intra-subnet flow (student ↔ student)
h1 and h2 share `10.0.1.0/24`, so h1 treats h2 as on-link and ARPs for it
directly (no gateway). The starter sets a static ARP only for the gateway, so
add a peer ARP entry once before this test:
```
mininet> h1 ip neigh add 10.0.1.20 lladdr 00:00:00:00:01:20 dev h1-eth0 nud permanent
mininet> h2 ip neigh add 10.0.1.10 lladdr 00:00:00:00:01:10 dev h2-eth0 nud permanent
mininet> h1 ping -c3 h2     # Student <-> Student : PASS
```

### 4.3 Security policy — blocked flows should fail (100% loss)
```
mininet> h1 ping -c3 h5     # Student  -> Admin : blocked
mininet> h6 ping -c3 h5     # External -> Admin : blocked (extra policy)
```

### 4.4 DSCP marking — capture on the receiver
```
mininet> h5 tcpdump -i h5-eth0 -vv -n icmp &
mininet> h3 ping -c2 h5           # ICMP -> Interactive -> tos 0xb8 (DSCP 46)
```
UDP service (DSCP 26) and Web (DSCP 34):
```
mininet> h5 iperf -s -u &
mininet> h4 iperf -c 10.0.4.50 -u -b 1M -t 2     # UDP -> tos 0x68 (DSCP 26)
mininet> h5 tcpdump -i h5-eth0 -vv -n tcp &
mininet> h5 iperf -s & ; mininet> h3 iperf -c 10.0.4.50 -t 2   # TCP (staff->admin)
```

### 4.5 TTL behaviour
```
mininet> h3 ping -c2 -t 1 h5     # TTL=1 -> decremented to 0 -> dropped (expired)
mininet> h3 ping -c2 h5          # normal TTL -> forwarded, TTL-1 in tcpdump
```

### 4.6 Negative test — unknown destination
```
mininet> h3 ping -c2 10.0.9.99   # no LPM entry -> default_action drop -> 100% loss
```

### Saving evidence (for the zip)
```bash
# capture with DSCP (h5 is on switch port s1-eth5):
sudo tcpdump -i s1-eth5 -vv -n -w captures/dscp_icmp.pcap icmp
# copy each mininet test's console output into evidence/terminal-outputs.txt
```

## Notes / limitations
- Tables are static (no dynamic control plane), as required.
- IPv6 is not handled; only IPv4 is parsed and forwarded.
- BMv2 is a functional model, not a performance benchmark.
- The switch does not answer ARP; inter-subnet traffic relies on the gateway
  ARP entry set by the topology, and the intra-subnet test needs the one-line
  peer ARP entry shown in 4.2.

---
Based on the CN HW3 P4 Data Plane starter by Parmis Hemasian, licensed under the
Apache License 2.0. This README has been rewritten and modified for this
submission.
