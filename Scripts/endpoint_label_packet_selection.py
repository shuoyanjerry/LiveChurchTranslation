#!/usr/bin/env python3
"""Pinned identities and deterministic stratified ordering for boundary review."""

from __future__ import annotations

import hashlib
from collections import Counter, defaultdict

PLAN_SHA256 = "719abbaa22cb564721ffcd9c78a02a4d9d1f6de9359b386552919dd2a59fc624"
MANIFEST_SHA256 = "8a485214b1c3fe01a931ec52bf14a59d409c3746b4e2e33dd28d0a80858302c8"
PINNED_SEED = "endpoint-human-boundary-v1-2026-08-22"
EXPECTED_STRATA = {
    "acoustic-control": 16,
    "long-counterexample": 24,
    "long-early-cut": 24,
    "mapping-audit": 20,
}


def stable_digest(seed: str, domain: str, value: str) -> str:
    payload = f"{seed}\0{domain}\0{value}".encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def blinded_order(samples: list[dict], seed: str) -> list[dict]:
    groups: dict[str, list[dict]] = defaultdict(list)
    for sample in samples:
        groups[sample["stratum"]].append(sample)
    for group in groups.values():
        group.sort(
            key=lambda item: stable_digest(seed, "order", item["sampleID"])
        )
    strata = sorted(
        groups,
        key=lambda item: stable_digest(seed, "stratum", item),
    )
    ordered: list[dict] = []
    while any(groups.values()):
        for stratum in strata:
            if groups[stratum]:
                ordered.append(groups[stratum].pop(0))
    return ordered


def validate_inputs(plan: dict, enforce_pins: bool) -> None:
    samples = plan.get("samples", [])
    if len(samples) != plan.get("selection", {}).get("sampleCount"):
        raise ValueError("manual plan cardinality mismatch")
    identifiers = [sample["sampleID"] for sample in samples]
    if len(identifiers) != len(set(identifiers)):
        raise ValueError("duplicate manual plan sample identity")
    if enforce_pins:
        counts = Counter(sample["stratum"] for sample in samples)
        if len(samples) != 84 or dict(counts) != EXPECTED_STRATA:
            raise ValueError("frozen 84-event stratum contract mismatch")
        if plan["sourceInputSHA256"]["manifest"] != MANIFEST_SHA256:
            raise ValueError("manual plan source-manifest binding mismatch")
