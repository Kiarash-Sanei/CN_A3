#!/usr/bin/env python3
import argparse
import os
import subprocess
import sys
import time

from mininet.cli import CLI
from mininet.link import TCLink
from mininet.net import Mininet
from mininet.node import Host, Switch
from mininet.topo import Topo
from mininet.log import setLogLevel, info


class P4Switch(Switch):
    """A minimal BMv2 simple_switch wrapper for Mininet."""

    def __init__(self, name, json_path, thrift_port=9090, **kwargs):
        super().__init__(name, **kwargs)
        self.json_path = json_path
        self.thrift_port = thrift_port
        self.process = None

    def start(self, controllers):
        if not os.path.isfile(self.json_path):
            raise FileNotFoundError(f"P4 JSON not found: {self.json_path}")

        intf_args = []
        for port, intf in sorted(self.intfs.items()):
            if port == 0:
                continue
            intf_args.extend(["-i", f"{port}@{intf.name}"])

        cmd = [
            "simple_switch",
            "--thrift-port",
            str(self.thrift_port),
            *intf_args,
            self.json_path,
        ]
        info(f"*** Starting {self.name}: {' '.join(cmd)}\n")
        log_path = f"/tmp/{self.name}-simple_switch.log"
        log_file = open(log_path, "w", encoding="utf-8")
        self.process = subprocess.Popen(cmd, stdout=log_file, stderr=subprocess.STDOUT)
        self.log_file = log_file
        info(f"*** BMv2 log: {log_path}\n")
        time.sleep(1)

    def stop(self, deleteIntfs=True):
        if self.process is not None:
            self.process.terminate()
            try:
                self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.process.kill()
        if getattr(self, "log_file", None) is not None:
            self.log_file.close()
        super().stop(deleteIntfs)


class CampusTopo(Topo):
    def build(self, json_path):
        switch = self.addSwitch("s1", cls=P4Switch, json_path=json_path)

        hosts = [
            ("h1", "10.0.1.10/24", "00:00:00:00:01:10", "10.0.1.1"),
            ("h2", "10.0.1.20/24", "00:00:00:00:01:20", "10.0.1.1"),
            ("h3", "10.0.2.30/24", "00:00:00:00:02:30", "10.0.2.1"),
            ("h4", "10.0.3.40/24", "00:00:00:00:03:40", "10.0.3.1"),
            ("h5", "10.0.4.50/24", "00:00:00:00:04:50", "10.0.4.1"),
            ("h6", "10.0.5.60/24", "00:00:00:00:05:60", "10.0.5.1"),
        ]

        for name, ip, mac, _gateway in hosts:
            host = self.addHost(name, cls=Host, ip=ip, mac=mac)
            self.addLink(host, switch, cls=TCLink)


def configure_hosts(net):
    gateways = {
        "h1": "10.0.1.1",
        "h2": "10.0.1.1",
        "h3": "10.0.2.1",
        "h4": "10.0.3.1",
        "h5": "10.0.4.1",
        "h6": "10.0.5.1",
    }

    for host_name, gateway in gateways.items():
        host = net.get(host_name)
        host.cmd("ip route flush root 0/0")
        host.cmd(f"ip route add default via {gateway} dev {host_name}-eth0")
        # Students may replace static ARP entries with their own design/testing method.
        host.cmd(f"ip neigh add {gateway} lladdr 00:aa:bb:00:00:01 dev {host_name}-eth0 nud permanent || true")


def run(json_path, cli=True):
    topo = CampusTopo(json_path=os.path.abspath(json_path))
    net = Mininet(topo=topo, controller=None, autoSetMacs=False, autoStaticArp=False)
    net.start()
    configure_hosts(net)
    info("*** Hosts: h1/h2 student, h3 staff, h4 research, h5 admin server, h6 external\n")
    info("*** BMv2 thrift port: 9090\n")
    if cli:
        CLI(net)
    net.stop()


def main():
    parser = argparse.ArgumentParser(description="Single-switch P4 campus topology")
    parser.add_argument("--json", required=True, help="Compiled BMv2 JSON file")
    parser.add_argument("--no-cli", action="store_true", help="Start and stop without interactive CLI")
    args = parser.parse_args()

    setLogLevel("info")
    run(args.json, cli=not args.no_cli)


if __name__ == "__main__":
    sys.exit(main())
