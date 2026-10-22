#!/usr/bin/env python3
"""Render an additive candidate; never edit the live Traefik file.

Run on the VPS (PyYAML is installed). Keep the original bytes of every existing
configuration node, reject name/domain collisions, then verify the parsed diff.
TLS issuance is an explicit second step, after public A/AAAA checks.
"""
import argparse
import copy
import hashlib
import ipaddress
import json
import re
import urllib.request
from pathlib import Path

import yaml

DOMAIN = "staging.meskm.fr"
VPS_IP = "178.33.206.185"
ROUTERS = {"meskm-http", "meskm-https"}
SERVICE = "meskm-static"


def candidate(raw, acme=False):
    before = yaml.safe_load(raw)
    after = copy.deepcopy(before)
    http = after["http"]
    routers, services = http["routers"], http["services"]
    if ROUTERS.intersection(routers) or SERVICE in services:
        raise ValueError("Mes Km names already exist; audit before updating")
    for router in routers.values():
        if "meskm.fr" in router.get("rule", ""):
            raise ValueError("An existing router already handles Mes Km")
    if "https-only" not in http.get("middlewares", {}):
        raise ValueError("Expected existing HTTPS redirect middleware")
    rule = f"Host(`{DOMAIN}`)"
    routers["meskm-http"] = {
        "rule": rule, "entryPoints": ["http"],
        "middlewares": ["https-only"], "service": "noop@internal",
    }
    routers["meskm-https"] = {
        "rule": rule, "entryPoints": ["https"], "service": SERVICE,
        "tls": {"certResolver": "public"} if acme else {},
    }
    services[SERVICE] = {"loadBalancer": {
        "servers": [{"url": "http://meskm-web:8080"}],
        "healthCheck": {"path": "/healthz", "interval": "20s", "timeout": "3s"},
    }}
    # Insert beneath the existing mapping keys, leaving all original lines intact.
    rendered = raw
    for key, nodes in [("routers", {k: routers[k] for k in sorted(ROUTERS)}),
                       ("services", {SERVICE: services[SERVICE]})]:
        anchor = f"  {key}:\n"
        if rendered.count(anchor) != 1:
            raise ValueError(f"Expected exactly one {key} anchor")
        block = yaml.safe_dump(nodes, sort_keys=False)
        block = "".join("    " + line if line.strip() else line
                        for line in block.splitlines(keepends=True))
        rendered = rendered.replace(anchor, anchor + block, 1)
    if yaml.safe_load(rendered) != after:
        raise ValueError("Candidate differs from the intended additive mapping")
    stripped = copy.deepcopy(yaml.safe_load(rendered))
    for name in ROUTERS:
        del stripped["http"]["routers"][name]
    del stripped["http"]["services"][SERVICE]
    if stripped != before:
        raise ValueError("Existing configuration changed")
    return rendered


def verify_dns():
    # DNS over HTTPS avoids installing DNS utilities on the shared VPS.
    for resolver in ["https://cloudflare-dns.com/dns-query", "https://dns.google/resolve"]:
        answers = {}
        for record, rrtype in [("A", 1), ("AAAA", 28)]:
            request = urllib.request.Request(
                f"{resolver}?name={DOMAIN}&type={record}",
                headers={"Accept": "application/dns-json"},
            )
            with urllib.request.urlopen(request, timeout=15) as response:
                result = json.load(response)
            if result.get("Status") != 0:
                raise ValueError(f"DNS not ready at {resolver}: {result.get('Status')}")
            answers[record] = sorted({
                str(ipaddress.ip_address(rr["data"]))
                for rr in result.get("Answer", []) if rr["type"] == rrtype
            })
        if answers != {"A": [VPS_IP], "AAAA": []}:
            raise ValueError(f"DNS not ready at {resolver}: {answers}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--enable-acme", action="store_true")
    args = parser.parse_args()
    raw = args.baseline.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if not re.fullmatch(r"[0-9a-f]{64}", args.expected_sha256) or digest != args.expected_sha256:
        raise ValueError("Baseline changed since the audit")
    if args.baseline.resolve() == args.output.resolve():
        raise ValueError("Refusing to overwrite the baseline")
    if args.enable_acme:
        verify_dns()
    rendered = candidate(raw.decode(), args.enable_acme)
    with args.output.open("x") as output:
        output.write(rendered)
    print(json.dumps({"candidate": str(args.output), "baseline_sha256": digest,
                      "domain": DOMAIN, "acme": args.enable_acme,
                      "existing_configuration_unchanged": True}))


if __name__ == "__main__":
    main()
