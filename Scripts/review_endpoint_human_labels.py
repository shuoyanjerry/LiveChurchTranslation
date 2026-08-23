#!/usr/bin/env python3
"""Minimal offline audio review CLI; persists only private enumerated labels."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from pathlib import Path

from endpoint_label_packet_io import read_json

CHOICES = {
    "semanticCompletion": [
        "definitely_complete",
        "probably_complete",
        "uncertain",
        "probably_incomplete",
        "definitely_incomplete",
    ],
    "audiblePause": [
        "none",
        "under_300ms",
        "300_to_499ms",
        "500_to_649ms",
        "650ms_or_more",
        "uncertain",
    ],
    "cutDecision": ["safe", "unsafe", "abstain"],
    "wordCut": ["yes", "no", "uncertain"],
    "speakerChange": ["yes", "no", "uncertain"],
    "noise": ["yes", "no", "uncertain"],
}


def save_private(path: Path, value: dict) -> None:
    data = (json.dumps(value, ensure_ascii=True, sort_keys=True, indent=2) + "\n").encode()
    temporary = path.parent / f".{path.name}.tmp"
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    temporary.chmod(0o600)
    os.replace(temporary, path)
    path.chmod(0o600)


def choose(name: str, values: list[str]) -> str:
    while True:
        print(f"{name}: " + "  ".join(f"{index + 1}={value}" for index, value in enumerate(values)))
        answer = input("> ").strip()
        if answer.isdigit() and 1 <= int(answer) <= len(values):
            return values[int(answer) - 1]
        print("Choose one listed number.")


def play_command(path: Path, end_at_seconds: float | None = None) -> list[str]:
    command = ["/usr/bin/afplay"]
    if end_at_seconds is not None:
        command.extend(["-t", f"{end_at_seconds:.6f}"])
    command.append(str(path))
    return command


def play(path: Path, end_at_seconds: float | None = None) -> None:
    if not Path("/usr/bin/afplay").exists():
        print("Audio playback is unavailable on this host.")
        return
    subprocess.run(
        play_command(path, end_at_seconds),
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def load_state(packet: Path, annotator: str, template: dict) -> tuple[Path, dict]:
    labels_dir = packet / "labels"
    labels_dir.mkdir(mode=0o700, exist_ok=True)
    labels_dir.chmod(0o700)
    destination = labels_dir / f"{annotator}.json"
    if destination.exists():
        state = read_json(destination)
        if state.get("packetID") != template["packetID"] or state.get("annotatorID") != annotator:
            raise ValueError("existing label identity mismatch")
        return destination, state
    state = dict(template)
    state["annotatorID"] = annotator
    save_private(destination, state)
    return destination, state


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--packet", type=Path, default=Path(".artifacts/endpoint-human-labels"))
    parser.add_argument("--annotator", required=True)
    arguments = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,32}", arguments.annotator):
        raise ValueError("annotator ID must use 1-32 letters, numbers, underscores, or hyphens")
    manifest = read_json(arguments.packet / "reviewer-manifest.json")
    template = read_json(arguments.packet / "labels-template.json")
    destination, state = load_state(arguments.packet, arguments.annotator, template)
    items = {item["blindID"]: item for item in manifest["items"]}
    index = 0
    while index < len(state["labels"]):
        label = state["labels"][index]
        item = items[label["blindID"]]
        completed = label["semanticCompletion"] is not None
        seconds = item["boundaryOffsetSamples"] / item["sampleRateHz"]
        status = "yes" if completed else "no"
        print(
            f"{index + 1}/{len(state['labels'])} {label['blindID']} "
            f"boundary={seconds:.3f}s labeled={status}"
        )
        action = input(
            "[p]lay-full [e]nd-at-boundary [l]abel [n]ext [b]ack [q]uit > "
        ).strip().lower()
        if action == "p":
            play(arguments.packet / item["audioFile"])
        elif action == "e":
            play(arguments.packet / item["audioFile"], seconds)
        elif action == "l":
            for name, values in CHOICES.items():
                label[name] = choose(name, values)
            save_private(destination, state)
            index += 1
        elif action == "n":
            index += 1
        elif action == "b":
            index = max(0, index - 1)
        elif action == "q":
            save_private(destination, state)
            return
    save_private(destination, state)
    print("Review queue reached its end; unresolved items remain null until explicitly labeled.")


if __name__ == "__main__":
    main()
