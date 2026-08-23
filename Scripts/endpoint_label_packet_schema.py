#!/usr/bin/env python3
"""Strict completed-label JSON schema for the private annotation packet."""

from __future__ import annotations


def label_schema(packet_id: str, blind_ids: list[str]) -> dict:
    yes_no = {
        "enum": ["yes", "no", "uncertain"],
        "type": "string",
    }
    completion = {
        "enum": [
            "definitely_complete",
            "probably_complete",
            "uncertain",
            "probably_incomplete",
            "definitely_incomplete",
        ]
    }
    pause = {
        "enum": [
            "none",
            "under_300ms",
            "300_to_499ms",
            "500_to_649ms",
            "650ms_or_more",
            "uncertain",
        ]
    }
    required_labels = [
        "blindID",
        "semanticCompletion",
        "audiblePause",
        "cutDecision",
        "wordCut",
        "speakerChange",
        "noise",
    ]
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "additionalProperties": False,
        "properties": {
            "annotatorID": {
                "pattern": "^[A-Za-z0-9_-]{1,32}$",
                "type": "string",
            },
            "labels": {
                "items": {
                    "additionalProperties": False,
                    "properties": {
                        "audiblePause": pause,
                        "blindID": {"enum": blind_ids},
                        "cutDecision": {
                            "enum": ["safe", "unsafe", "abstain"]
                        },
                        "noise": yes_no,
                        "semanticCompletion": completion,
                        "speakerChange": yes_no,
                        "wordCut": yes_no,
                    },
                    "required": required_labels,
                    "type": "object",
                },
                "maxItems": len(blind_ids),
                "minItems": len(blind_ids),
                "type": "array",
            },
            "packetID": {"const": packet_id},
            "schemaVersion": {"const": 1},
        },
        "required": ["schemaVersion", "packetID", "annotatorID", "labels"],
        "type": "object",
    }
