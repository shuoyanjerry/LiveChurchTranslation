#!/usr/bin/env python3
"""Materialize the frozen 84-event private endpoint review packet."""

from __future__ import annotations

import argparse
from pathlib import Path

from endpoint_label_packet_core import PINNED_SEED, build_packet


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--plan",
        type=Path,
        default=Path(
            ".artifacts/endpoint-analysis/manual-label-plan-v1.json"
        ),
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path(
            ".artifacts/asr-qualification/public-domain-mandarin-scripture-v2.json"
        ),
    )
    parser.add_argument("--artifact-root", type=Path, default=Path(".artifacts"))
    parser.add_argument("--output", type=Path, default=Path(".artifacts/endpoint-human-labels"))
    parser.add_argument("--seed", default=PINNED_SEED)
    arguments = parser.parse_args()
    result = build_packet(
        arguments.plan,
        arguments.manifest,
        arguments.artifact_root,
        arguments.output,
        arguments.seed,
    )
    print(
        " ".join(
            [
                f"clips={result['audioClipCount']}",
                f"packet_sha256={result['packetAggregateSHA256']}",
                f"mapping_sha256={result['mappingSHA256']}",
                f"attestation_sha256={result['attestationSHA256']}",
                "mode=0600",
            ]
        )
    )


if __name__ == "__main__":
    main()
