# CN HW3 — P4 Data Plane (BMv2 / Mininet)

Programmable edge switch `s1` that parses packets, forwards IPv4 by longest
prefix match, classifies traffic, marks DSCP for QoS, and enforces security
policy — entirely in the data plane. No routing protocol / control-plane
algorithm is used; tables are filled with static entries.

## Files
```
src/dataplane.p4     # the P4-16 program (v1model / simple_switch)
src/s1-commands.txt  # static table entries (simple_switch_CLI format)
src/README.md        # this file
```

## 0. Prerequisites
Use the course Docker image (BMv2 + Mininet + p4c). Everything below runs
inside `/workspace` in that container.

```bash
docker rm p4-dataplane-hw
docker buildx build --platform linux/amd64 --load -t p4-dataplane-hw .
docker run --rm -it --platform linux/amd64 --privileged -v "$PWD":/workspace p4-dataplane-hw
docker/verify-env.sh          # sanity check of the tools
```

## 1. Compile the P4 program
```bash
starter/scripts/compile.sh src/dataplane.p4
# produces dataplane.json (the BMv2 target used by run_mininet.sh)
```

## 2. Start the topology (switch s1 + 6 hosts)
```bash
starter/scripts/run_mininet.sh dataplane.json
```
This drops you into the `mininet>` prompt with `s1` running the compiled program.

## 3. Load the static table entries into s1
In a **second terminal** inside the same container:
```bash
simple_switch_CLI --thrift-port 9090 < src/s1-commands.txt
```
> The Thrift port is the one `run_mininet.sh` prints for `s1` (often 9090).
> If `s1` uses a different port, pass that value.

**Verify the port/MAC map matches your topology** before trusting results:
```
mininet> net
mininet> h1 ifconfig ; h5 ifconfig
```
If any host MAC differs from `src/s1-commands.txt`, edit the `ipv4_forward`
lines to match. If your hosts don't already have routes/ARP to reach other
subnets, add (per host, adjust the last-hop MAC to that host's real MAC):
```
mininet> h1 ip route add default dev h1-eth0
mininet> h1 arp -s 10.0.4.50 08:00:00:00:04:32   # example
```
(The starter topology usually configures this for you.)

## 4. Tests and evidence

### 4.1 Forwarding — allowed flows should succeed
```
mininet> h3 ping -c3 h5     # Staff  -> Admin  : PASS
mininet> h1 ping -c3 h2     # Student<->Student : PASS
mininet> h4 ping -c3 h6     # Research-> Ext   : PASS
```

### 4.2 Security policy — blocked flows should fail
```
mininet> h1 ping -c3 h5     # Student -> Admin : 100% loss (blocked)
mininet> h6 ping -c3 h5     # External-> Admin : 100% loss (my extra policy)
```

### 4.3 DSCP marking — capture and inspect
```
mininet> h5 tcpdump -i h5-eth0 -vv -n icmp   &   # in one xterm
mininet> h3 ping -c2 h5                          # ICMP -> Interactive -> DSCP 46 (EF)
```
For UDP-service (DSCP 26) and Web (DSCP 34):
```
mininet> h5 iperf -s -u &            ; mininet> h4 iperf -c h5 -u   # UDP -> DSCP 26
mininet> h5 tcpdump -i h5-eth0 -vv -n 'tcp port 80'  &
mininet> h4 python3 -m http.server 80 & ; h3 curl 10.0.4.50        # (if h3->admin allowed) DSCP 34
```
Look for `tos 0xb8` (=46<<2, EF), `tos 0x68` (=26<<2, AF31), `tos 0x88`
(=34<<2, AF41) in the tcpdump output.

### 4.4 TTL behaviour
```
mininet> h1 ping -c3 -t 1 h2    # TTL=1 leaves h1; switch decrements to 0 -> drop (expired)
mininet> h1 ping -c3 h2         # normal TTL -> forwarded, TTL decremented by 1 (see tcpdump)
```

### 4.5 Negative test — unknown destination
```
mininet> h1 ping -c3 10.0.9.99  # no LPM entry -> default_action drop -> 100% loss
```

### Saving evidence (for the zip)
```bash
# packet capture with DSCP:
mininet> h5 tcpdump -i h5-eth0 -vv -n -w /workspace/captures/dscp_icmp.pcap icmp &
# terminal output:  copy/paste each test's result into evidence/terminal-outputs.txt
```

## Pipeline (order of tables)
```
parse -> sec_policy(ternary) -> classify(ternary) -> qos_mark(exact)
      -> TTL check -> ipv4_lpm(LPM: forward + MAC rewrite + TTL--)
      -> deparse + IPv4 checksum recompute
```
Firewall runs first so forbidden packets are dropped before any forwarding /
marking work. Classification result travels to the QoS stage through
`meta.class_id`. Full design discussion is in `report.pdf`.

## Match-kind choices
- `sec_policy` : **ternary** — needs wildcards on src/dst prefixes.
- `classify`   : **ternary** — matches (protocol, port) with don't-cares.
- `qos_mark`   : **exact**   — class_id is a small exact key.
- `ipv4_lpm`   : **LPM**     — longest-prefix forwarding on dst IPv4.

## Notes / limitations
- Tables are static (no dynamic control plane), as required.
- IPv6 is not handled; only IPv4 is parsed/forwarded.
- BMv2 is a functional model, not a performance benchmark.
- Host MAC/port map in `s1-commands.txt` must match the starter topology.
