#!/usr/bin/env python3
"""Integrity and blinding checks for the materialized private packet."""

from __future__ import annotations

import hashlib
import json
import os
import stat
import sys
import unittest
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))

from endpoint_label_packet_io import canonical_json, sha256_file  # noqa: E402


class MaterializedPacketTests(unittest.TestCase):
    def test_materialized_packet_contract(self) -> None:
        packet = Path(
            os.environ.get(
                "ENDPOINT_LABEL_PACKET",
                ROOT / ".artifacts/endpoint-human-labels",
            )
        )
        if not packet.exists():
            self.skipTest("private packet has not been materialized")
        reviewer = json.loads((packet / "reviewer-manifest.json").read_text())
        sealed_path = packet / ".sealed/identity-map.json"
        sealed = json.loads(sealed_path.read_text())
        template = json.loads((packet / "labels-template.json").read_text())
        plan = json.loads(
            (ROOT / ".artifacts/endpoint-analysis/manual-label-plan-v1.json").read_text()
        )
        manifest = json.loads(
            (
                ROOT
                / ".artifacts/asr-qualification/public-domain-mandarin-scripture-v2.json"
            ).read_text()
        )
        attestation = json.loads((packet / "attestation.json").read_text())
        self.assertEqual(len(reviewer["items"]), 84)
        self.assertEqual(len(sealed["mapping"]), 84)
        identities = [
            (
                item["sourceAudioSHA256"],
                item["sourceRange"]["startSample"],
                item["sourceRange"]["endSampleExclusive"],
            )
            for item in sealed["mapping"]
        ]
        self.assertEqual(len(identities), len(set(identities)))
        self.assertTrue(
            all(
                0
                <= item["sourceRange"]["startSample"]
                < item["boundaryAbsoluteSample"]
                <= item["sourceRange"]["endSampleExclusive"]
                <= item["sourceTotalSamples"]
                for item in sealed["mapping"]
            )
        )
        first_sixty_four = [item["stratum"] for item in sealed["mapping"][:64]]
        self.assertTrue(
            all(
                first_sixty_four.count(name) == 16
                for name in sealed["stratumCounts"]
            )
        )
        self.assertTrue(
            all(
                label["semanticCompletion"] is None
                and label["wordCut"] is None
                and label["speakerChange"] is None
                and label["noise"] is None
                for label in template["labels"]
            )
        )
        blind_text = json.dumps(
            {
                "attestation": attestation,
                "reviewer": reviewer,
                "schema": json.loads((packet / "label-schema.json").read_text()),
                "template": template,
            }
        )
        forbidden = [
            "boundaryAbsoluteSample",
            "boundaryFamily",
            "clipID",
            "mappingConfidence",
            "proxyClass",
            "sequence",
            "completionProbability",
            "sourceAudioSHA256",
            "sourceInputSHA256",
            "sourceManifestSHA256",
            "sourcePlanSHA256",
            "sourceRange",
            "sourceTotalSamples",
            "stratum",
            "task",
        ]
        self.assertTrue(
            all(token.lower() not in blind_text.lower() for token in forbidden)
        )
        source_text = [
            str(value)
            for sample in plan["samples"]
            for key, value in sample.items()
            if key in {"referenceContext", "proxyEvidence"} and value
        ]
        self.assertTrue(
            all(value not in blind_text for value in source_text),
            "reviewer packet contains source text",
        )
        expected_sources = {clip["audioSHA256"] for clip in manifest["clips"]}
        self.assertEqual(
            {item["sourceAudioSHA256"] for item in sealed["mapping"]},
            expected_sources,
        )
        self.assertTrue(all(value not in blind_text for value in expected_sources))
        self.assertEqual(len(list((packet / "audio").glob("*.wav"))), 84)
        hashed_files = []
        for item in reviewer["items"]:
            audio = packet / item["audioFile"]
            self.assertEqual(sha256_file(audio), item["audioWAVSHA256"])
            with wave.open(str(audio), "rb") as source:
                frames = source.readframes(source.getnframes())
                self.assertEqual(source.getnframes(), item["clipFrameCount"])
                self.assertEqual(
                    (
                        source.getnchannels(),
                        source.getsampwidth(),
                        source.getframerate(),
                    ),
                    (1, 2, item["sampleRateHz"]),
                )
            self.assertEqual(
                hashlib.sha256(frames).hexdigest(),
                item["audioPCM16SHA256"],
            )
            hashed_files.append(
                {"path": item["audioFile"], "sha256": item["audioWAVSHA256"]}
            )
        for name in [
            "label-schema.json",
            "labels-template.json",
            "reviewer-manifest.json",
            ".sealed/identity-map.json",
            "README.txt",
        ]:
            hashed_files.append({"path": name, "sha256": sha256_file(packet / name)})
        aggregate = hashlib.sha256(
            canonical_json(sorted(hashed_files, key=lambda item: item["path"]))
        ).hexdigest()
        self.assertEqual(aggregate, attestation["packetAggregateSHA256"])
        self.assertEqual(attestation["hashedPayloadFileCount"], 89)
        self.assertEqual(
            attestation["sealedProvenanceSHA256"],
            sha256_file(sealed_path),
        )
        self.assertEqual(len([path for path in packet.rglob("*") if path.is_file()]), 90)
        for path in packet.rglob("*"):
            mode = stat.S_IMODE(path.stat().st_mode)
            self.assertEqual(mode, 0o700 if path.is_dir() else 0o600)


if __name__ == "__main__":
    unittest.main()
