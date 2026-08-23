#!/usr/bin/env python3
"""Private, deterministic file and WAV helpers for endpoint label packets."""

from __future__ import annotations

import hashlib
import json
import os
import wave
from pathlib import Path


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while block := stream.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()


def canonical_json(value: object) -> bytes:
    return (
        json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def pretty_json(value: object) -> bytes:
    return (
        json.dumps(value, ensure_ascii=True, sort_keys=True, indent=2) + "\n"
    ).encode("utf-8")


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as stream:
        value = json.load(stream)
    if not isinstance(value, dict):
        raise ValueError("JSON root must be an object")
    return value


def make_private_directory(path: Path) -> None:
    path.mkdir(mode=0o700, parents=True, exist_ok=False)
    path.chmod(0o700)


def write_private(path: Path, data: bytes) -> None:
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        raise
    path.chmod(0o600)


def write_private_json(path: Path, value: object) -> None:
    write_private(path, pretty_json(value))


def find_source_wavs(root: Path, clips: list[dict]) -> dict[str, Path]:
    expected = {clip["audioSHA256"] for clip in clips}
    matches: dict[str, list[Path]] = {digest: [] for digest in expected}
    for candidate in root.rglob("*"):
        if not candidate.is_file() or candidate.suffix.lower() != ".wav":
            continue
        digest = sha256_file(candidate)
        if digest in matches:
            matches[digest].append(candidate)
    missing = sum(not paths for paths in matches.values())
    if missing:
        raise ValueError(f"missing frozen source WAV identities: {missing}")
    return {digest: sorted(paths)[0] for digest, paths in matches.items()}


def validate_source(path: Path, clip: dict) -> None:
    with wave.open(str(path), "rb") as source:
        actual = (
            source.getnchannels(),
            source.getsampwidth(),
            source.getframerate(),
            source.getnframes(),
        )
    expected = (1, 2, clip["sampleRate"], clip["totalSamples"])
    if actual != expected:
        raise ValueError("frozen source WAV format or sample count mismatch")


def extract_wav(
    source_path: Path,
    destination: Path,
    start_sample: int,
    end_sample: int,
    sample_rate: int,
) -> tuple[str, str]:
    with wave.open(str(source_path), "rb") as source:
        source.setpos(start_sample)
        frames = source.readframes(end_sample - start_sample)
    if len(frames) != (end_sample - start_sample) * 2:
        raise ValueError("short source WAV read")
    descriptor = os.open(
        destination,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL,
        0o600,
    )
    with os.fdopen(descriptor, "w+b") as stream:
        with wave.open(stream, "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(sample_rate)
            output.writeframes(frames)
        stream.flush()
        os.fsync(stream.fileno())
    destination.chmod(0o600)
    return sha256_file(destination), sha256_bytes(frames)
