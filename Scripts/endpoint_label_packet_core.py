#!/usr/bin/env python3
"""Build a blind, local-only human endpoint annotation packet."""

from __future__ import annotations
import os
import shutil
import tempfile
from pathlib import Path
from endpoint_label_packet_io import (
    canonical_json,
    extract_wav,
    find_source_wavs,
    make_private_directory,
    read_json,
    sha256_bytes,
    sha256_file,
    validate_source,
    write_private,
    write_private_json,
)
from endpoint_label_packet_models import (
    attestation_document,
    reviewer_document,
    reviewer_item,
    sealed_document,
    sealed_item,
    template_document,
)
from endpoint_label_packet_schema import label_schema
from endpoint_label_packet_selection import (
    MANIFEST_SHA256,
    PINNED_SEED,
    PLAN_SHA256,
    blinded_order,
    stable_digest,
    validate_inputs,
)

def build_packet(
    plan_path: Path,
    manifest_path: Path,
    artifact_root: Path,
    output: Path,
    seed: str = PINNED_SEED,
    enforce_pins: bool = True,
) -> dict:
    plan_hash = sha256_file(plan_path)
    manifest_hash = sha256_file(manifest_path)
    if enforce_pins and (
        plan_hash != PLAN_SHA256 or manifest_hash != MANIFEST_SHA256
    ):
        raise ValueError("frozen plan or manifest SHA-256 mismatch")
    plan, manifest = read_json(plan_path), read_json(manifest_path)
    validate_inputs(plan, enforce_pins)
    clips = {clip["id"]: clip for clip in manifest["clips"]}
    sources = find_source_wavs(artifact_root, list(clips.values()))
    for clip in clips.values():
        validate_source(sources[clip["audioSHA256"]], clip)
    output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if output.exists():
        raise FileExistsError("output packet already exists")
    temporary = Path(
        tempfile.mkdtemp(prefix=".endpoint-label-packet-", dir=output.parent)
    )
    temporary.chmod(0o700)
    try:
        audio_dir, sealed_dir = temporary / "audio", temporary / ".sealed"
        make_private_directory(audio_dir)
        make_private_directory(sealed_dir)
        ordered = blinded_order(plan["samples"], seed)
        blind_ids = [
            "B" + stable_digest(seed, "blind", item["sampleID"])[:15]
            for item in ordered
        ]
        if len(blind_ids) != len(set(blind_ids)):
            raise ValueError("blind identity collision")
        packet_id = sha256_bytes(
            canonical_json(
                {
                    "manifest": manifest_hash,
                    "plan": plan_hash,
                    "seed": sha256_bytes(seed.encode()),
                }
            )
        )
        reviewer_items, mapping, file_hashes = [], [], []
        for order, (sample, blind_id) in enumerate(zip(ordered, blind_ids), 1):
            clip = clips[sample["clipID"]]
            segment = next(
                item
                for item in clip["segments"]
                if item["sequence"] == sample["sequence"]
            )
            start, end = sample["reviewStartSample"], sample["reviewEndSample"]
            if not (0 <= start < segment["endSample"] <= end <= clip["totalSamples"]):
                raise ValueError("manual review range is outside frozen source")
            if (
                sample["pcmSHA256"] != segment["pcmSHA256"]
                or sample["sampleRateHz"] != clip["sampleRate"]
            ):
                raise ValueError("manual sample-to-segment identity mismatch")
            relative = f"audio/{blind_id}.wav"
            wav_hash, pcm_hash = extract_wav(
                sources[clip["audioSHA256"]],
                temporary / relative,
                start,
                end,
                clip["sampleRate"],
            )
            file_hashes.append({"path": relative, "sha256": wav_hash})
            reviewer_items.append(
                reviewer_item(
                    relative,
                    wav_hash,
                    pcm_hash,
                    blind_id,
                    segment["endSample"] - start,
                    order,
                    clip["sampleRate"],
                    end - start,
                )
            )
            mapping.append(
                sealed_item(
                    sample,
                    clip,
                    segment,
                    blind_id,
                    order,
                    start,
                    end,
                )
            )
        schema = label_schema(packet_id, blind_ids)
        schema_bytes = canonical_json(schema)
        reviewer = reviewer_document(
            packet_id,
            reviewer_items,
            sha256_bytes(schema_bytes),
        )
        template = template_document(packet_id, blind_ids)
        sealed = sealed_document(
            packet_id,
            seed,
            mapping,
            plan_hash,
            manifest_hash,
            plan.get("sourceInputSHA256", {}),
            manifest.get("provenance", {}),
        )
        documents = [
            ("label-schema.json", schema),
            ("labels-template.json", template),
            ("reviewer-manifest.json", reviewer),
            (".sealed/identity-map.json", sealed),
        ]
        for name, value in documents:
            write_private_json(temporary / name, value)
            file_hashes.append(
                {"path": name, "sha256": sha256_file(temporary / name)}
            )
        readme = (
            b"Offline review: python3 Scripts/review_endpoint_human_labels.py "
            b"--annotator REVIEWER_ID\n"
            b"No label is prefilled or generated automatically.\n"
            b"Scope: frozen six-clip public Scripture Manifest V2. "
            b"This is challenger calibration only, not the >=12-sermon, "
            b">=8-hour, >=6-speaker release set.\n"
        )
        write_private(temporary / "README.txt", readme)
        file_hashes.append(
            {
                "path": "README.txt",
                "sha256": sha256_file(temporary / "README.txt"),
            }
        )
        aggregate = sha256_bytes(
            canonical_json(sorted(file_hashes, key=lambda item: item["path"]))
        )
        sealed_hash = sha256_file(temporary / ".sealed/identity-map.json")
        attestation = attestation_document(
            packet_id,
            len(blind_ids),
            len(file_hashes),
            aggregate,
            sealed_hash,
        )
        write_private_json(temporary / "attestation.json", attestation)
        os.rename(temporary, output)
        return {
            "attestationSHA256": sha256_file(output / "attestation.json"),
            "audioClipCount": len(blind_ids),
            "mappingSHA256": sealed_hash,
            "packetAggregateSHA256": aggregate,
        }
    except BaseException:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise
