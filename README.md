# Computer Networks HW3: P4 Data Plane Starter

This repository contains the starter environment for a practical homework in the Computer Networks course at the Department of Computer Engineering, Sharif University of Technology.

**Author:** Parmis Hemasian

The homework focuses on the network-layer data plane. You will use P4, BMv2 `simple_switch`, Mininet, Docker, and packet-capture tools to design and test a programmable switch.

The assignment handout is distributed separately by the course staff. It is not included in this repository. This repository only provides the runnable development environment and a minimal starter topology.

## What Is Included

- A Docker-based P4 development environment
- BMv2 / `simple_switch`
- Mininet topology with one programmable switch and six hosts
- A very small warmup P4 program
- Helper scripts for compiling, running, capturing traffic, testing the environment, and cleaning Mininet

## What Is Not Included

This repository does not contain the solution.

In particular, it does not provide:

- A completed IPv4 router
- Forwarding tables or route entries
- A firewall implementation
- A traffic classifier
- QoS / DSCP marking logic
- A complete P4 pipeline architecture

You are expected to design and implement the actual data-plane pipeline yourself.

## Repository Layout

```text
.
├── Dockerfile
├── docker/
│   ├── entrypoint.sh
│   ├── verify-env.sh
│   └── README.md
├── starter/
│   ├── README.md
│   ├── p4/
│   │   └── warmup_example.p4
│   ├── topology/
│   │   └── topology.py
│   ├── scripts/
│   │   ├── compile.sh
│   │   ├── run_mininet.sh
│   │   ├── cleanup.sh
│   │   ├── capture.sh
│   │   └── smoke_test.sh
│   └── config/
│       └── README.md
└── README.md
```

## Clone The Repository

Use the released version of the repository, not a random branch state:

```bash
git clone https://github.com/promise2-4/CN2026-HW3-P4-Dataplane.git
cd CN2026-HW3-P4-Dataplane
git checkout v1.0
```

## Build The Docker Image

Recommended command for Linux, macOS Intel, macOS Apple Silicon, and Windows with WSL2:

```bash
docker buildx build --platform linux/amd64 --load -t p4-dataplane-hw .
```

The P4 packages used by this Docker image are available for `linux/amd64`. On Apple Silicon, Docker Desktop runs the image through emulation.

## Start The Development Container

From the repository root:

```bash
docker run --rm -it --platform linux/amd64 --privileged -v "$PWD":/workspace p4-dataplane-hw
```

`--privileged` is needed because Mininet creates network namespaces, virtual Ethernet interfaces, and switch links inside the container.

If Docker gives the container a random name such as `great_johnson`, that is normal. Docker automatically generates names when `--name` is not provided.

## Verify The Environment

Inside the container, run:

```bash
docker/verify-env.sh
```

This checks that the main tools are available:

- `p4c`
- `simple_switch`
- `simple_switch_CLI`
- `mn`
- `python3`
- `tcpdump`
- `tshark`
- `scapy`

The script should end with:

```text
Environment verification passed.
```

## Compile The Warmup P4 Program

Inside the container:

```bash
starter/scripts/compile.sh starter/p4/warmup_example.p4
```

This should generate:

```text
starter/p4/warmup_example.json
```

The warmup program is intentionally tiny. It only demonstrates basic P4 structure and does not solve the homework.

## Run The Starter Topology

After compiling a P4 program:

```bash
starter/scripts/run_mininet.sh starter/p4/warmup_example.json
```

The topology contains one BMv2 switch, `s1`, and six hosts:

| Host | Role | IP address |
| --- | --- | --- |
| `h1` | Student subnet | `10.0.1.10/24` |
| `h2` | Student subnet | `10.0.1.20/24` |
| `h3` | Staff subnet | `10.0.2.30/24` |
| `h4` | Research subnet | `10.0.3.40/24` |
| `h5` | Admin server subnet | `10.0.4.50/24` |
| `h6` | External host | `10.0.5.60/24` |

This topology is only a starting point. Correct forwarding, filtering, classification, and QoS behavior must come from your own P4 program and runtime configuration.

## Run A Smoke Test

To check that the warmup program compiles and the topology can start:

```bash
starter/scripts/smoke_test.sh
```

This does not test the homework requirements. It only checks that the environment can compile a P4 program and start Mininet with BMv2.

## Capture Packets

Example:

```bash
starter/scripts/capture.sh h1-eth0
```

With a filter:

```bash
starter/scripts/capture.sh h5-eth0 "ip"
```

For DSCP verification, use `tcpdump -vv`, `tshark`, or Wireshark.

## Clean Mininet

If Mininet exits unexpectedly or leaves stale interfaces:

```bash
starter/scripts/cleanup.sh
```

## Platform Notes

Linux is the most reliable platform for Mininet. Docker Desktop on macOS and Windows usually works for this starter environment, but some Mininet networking behavior can differ from native Linux.

If you have persistent Mininet or packet-capture issues on macOS or Windows, use one of these options:

- Run the same Docker image inside a Linux VM
- Use WSL2 on Windows
- Use a Linux machine provided by the course staff

## Expected Submission

Follow the official assignment handout for the exact submission rules. In general, your submission should include:

- Your P4 source code
- Any runtime command/configuration files needed to load table entries
- Packet captures used as evidence
- Terminal outputs for your tests
- `report.pdf` with your design summary, test table, and known limitations
- A short demo video, if required by the handout

Do not submit only code. The assignment requires evidence that your data-plane behavior is correct.

## AI Tool Policy

You may use AI tools if allowed by the course policy, but you must understand everything you submit. You should be able to explain your pipeline, tables, actions, metadata, test results, and packet captures.

Code or text that you cannot explain may lose credit.

## License

This starter repository is released under the Apache License 2.0. This choice is intended to be compatible with the licensing style used across the main P4 open-source ecosystem, including [`p4lang/p4c`](https://github.com/p4lang/p4c), [`p4lang/behavioral-model`](https://github.com/p4lang/behavioral-model), and [`p4lang/tutorials`](https://github.com/p4lang/tutorials).

P4, BMv2, Mininet, Wireshark/TShark, Docker, and other tools used by this repository remain under their own upstream licenses. This repository does not claim ownership of those projects.
