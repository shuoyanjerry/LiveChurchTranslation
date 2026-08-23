#!/usr/bin/env python3
"""Privacy and reproducibility tests for the offline endpoint label packet."""

from __future__ import annotations

import hashlib
import json
import stat
import sys
import tempfile
import unittest
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))

from endpoint_label_packet_core import build_packet  # noqa: E402
from review_endpoint_human_labels import play_command, save_private  # noqa: E402


class SyntheticFixture:
    def __init__(self, root: Path) -> None:
        self.artifacts = root / "artifacts"
        self.artifacts.mkdir()
        source = self.artifacts / "source.wav"
        with wave.open(str(source), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(16_000)
            output.writeframes(b"\0\0" * 16_000)
        audio_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        strata = [
            "acoustic-control",
            "long-counterexample",
            "long-early-cut",
            "mapping-audit",
        ]
        segments, samples = [], []
        for index in range(8):
            start, end = index * 2_000, (index + 1) * 2_000
            pcm_hash = hashlib.sha256(f"pcm-{index}".encode()).hexdigest()
            segments.append(
                {
                    "endSample": end,
                    "pcmSHA256": pcm_hash,
                    "sequence": index,
                    "startSample": start,
                }
            )
            samples.append(
                {
                    "boundaryFamily": "hidden",
                    "clipID": "source-id",
                    "mappingConfidence": "hidden",
                    "pcmSHA256": pcm_hash,
                    "proxyClass": "hidden",
                    "reviewEndSample": end,
                    "reviewStartSample": start,
                    "sampleID": f"sample-{index}",
                    "sampleRateHz": 16_000,
                    "sequence": index,
                    "stratum": strata[index % 4],
                    "task": "hidden",
                }
            )
        manifest = {
            "clips": [
                {
                    "audioSHA256": audio_hash,
                    "id": "source-id",
                    "sampleRate": 16_000,
                    "segments": segments,
                    "totalSamples": 16_000,
                }
            ]
        }
        counts = {name: 2 for name in strata}
        plan = {"samples": samples, "selection": {"sampleCount": 8, "stratumCounts": counts}}
        self.plan, self.manifest = root / "plan.json", root / "manifest.json"
        self.plan.write_text(json.dumps(plan))
        self.manifest.write_text(json.dumps(manifest))

    def build(self, output: Path, seed: str) -> dict:
        return build_packet(self.plan, self.manifest, self.artifacts, output, seed, False)


class PacketTests(unittest.TestCase):
    def test_boundary_playback_command_stops_at_candidate(self) -> None:
        audio = Path("audio/B000.wav")
        self.assertEqual(
            play_command(audio, 12.25),
            ["/usr/bin/afplay", "-t", "12.250000", "audio/B000.wav"],
        )
        self.assertEqual(play_command(audio), ["/usr/bin/afplay", "audio/B000.wav"])

    def test_label_writer_uses_private_mode(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "labels.json"
            save_private(destination, {"labels": []})
            self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o600)
            self.assertEqual(len(list(Path(directory).iterdir())), 1)

    def test_randomization_is_deterministic_and_seeded(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture = SyntheticFixture(root)
            first = fixture.build(root / "first", "pinned")
            second = fixture.build(root / "second", "pinned")
            third = fixture.build(root / "third", "different")
            self.assertEqual(
                first["packetAggregateSHA256"],
                second["packetAggregateSHA256"],
            )
            one = json.loads((root / "first/reviewer-manifest.json").read_text())
            two = json.loads((root / "third/reviewer-manifest.json").read_text())
            self.assertNotEqual(
                [item["blindID"] for item in one["items"]],
                [item["blindID"] for item in two["items"]],
            )

if __name__ == "__main__":
    unittest.main()
