#!/usr/bin/env python3
"""Visible and sealed document models for endpoint human labeling."""

from __future__ import annotations

from collections import Counter


def reviewer_item(
    relative: str,
    wav_hash: str,
    pcm_hash: str,
    blind_id: str,
    boundary_offset: int,
    order: int,
    sample_rate: int,
    frame_count: int,
) -> dict:
    return {
        "audioFile": relative,
        "audioPCM16SHA256": pcm_hash,
        "audioWAVSHA256": wav_hash,
        "blindID": blind_id,
        "boundaryOffsetSamples": boundary_offset,
        "clipFrameCount": frame_count,
        "reviewOrder": order,
        "sampleRateHz": sample_rate,
    }


def sealed_item(
    sample: dict,
    clip: dict,
    segment: dict,
    blind_id: str,
    order: int,
    start: int,
    end: int,
) -> dict:
    return {
        "blindID": blind_id,
        "boundaryAbsoluteSample": segment["endSample"],
        "boundaryFamily": sample["boundaryFamily"],
        "clipID": sample["clipID"],
        "mappingConfidence": sample["mappingConfidence"],
        "proxyClass": sample["proxyClass"],
        "reviewOrder": order,
        "sampleID": sample["sampleID"],
        "sequence": sample["sequence"],
        "sourceAudioSHA256": clip["audioSHA256"],
        "sourceRange": {
            "endSampleExclusive": end,
            "startSample": start,
        },
        "sourceTotalSamples": clip["totalSamples"],
        "stratum": sample["stratum"],
        "task": sample["task"],
    }


def reviewer_document(
    packet_id: str,
    items: list[dict],
    schema_hash: str,
) -> dict:
    return {
        "instructions": [
            "Judge only the marked boundary from audio.",
            "The clip includes context before and after the marked sample.",
            "Do not infer a label from duration or clip identity.",
        ],
        "items": items,
        "labelSchemaCanonicalSHA256": schema_hash,
        "packetID": packet_id,
        "schemaVersion": 1,
    }


def template_document(packet_id: str, blind_ids: list[str]) -> dict:
    return {
        "annotatorID": None,
        "labels": [
            {
                "audiblePause": None,
                "blindID": blind_id,
                "cutDecision": None,
                "noise": None,
                "semanticCompletion": None,
                "speakerChange": None,
                "wordCut": None,
            }
            for blind_id in blind_ids
        ],
        "packetID": packet_id,
        "schemaVersion": 1,
    }


def sealed_document(
    packet_id: str,
    seed: str,
    mapping: list[dict],
    plan_hash: str,
    manifest_hash: str,
    source_inputs: dict,
    manifest_provenance: dict,
) -> dict:
    return {
        "mapping": mapping,
        "packetID": packet_id,
        "randomizationSeed": seed,
        "schemaVersion": 1,
        "sourceInputSHA256": source_inputs,
        "sourceManifestProvenance": manifest_provenance,
        "sourceManifestSHA256": manifest_hash,
        "sourcePlanSHA256": plan_hash,
        "stratumCounts": dict(
            Counter(item["stratum"] for item in mapping)
        ),
    }


def attestation_document(
    packet_id: str,
    clip_count: int,
    hashed_file_count: int,
    aggregate: str,
    sealed_hash: str,
) -> dict:
    return {
        "audioClipCount": clip_count,
        "corpusScope": "frozenPublicScriptureManifestV2SixClips",
        "hashedPayloadFileCount": hashed_file_count,
        "packetAggregateSHA256": aggregate,
        "packetID": packet_id,
        "qualificationScope": "challengerCalibrationOnly",
        "schemaVersion": 1,
        "sealedProvenanceSHA256": sealed_hash,
    }
