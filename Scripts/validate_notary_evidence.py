#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import pathlib
import stat
import uuid


class EvidenceError(ValueError):
    pass


def _object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise EvidenceError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _read_private_file(path, label):
    candidate = pathlib.Path(path)
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(candidate, flags)
    except OSError as error:
        raise EvidenceError(f"unsafe {label}: {candidate.name}") from error
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise EvidenceError(f"unsafe {label}: {candidate.name}")
        if stat.S_IMODE(metadata.st_mode) != 0o600 or metadata.st_uid != os.geteuid():
            raise EvidenceError(f"{label} must be an owner-only file: {candidate.name}")
        with os.fdopen(descriptor, "rb", closefd=False) as handle:
            return handle.read()
    finally:
        os.close(descriptor)


def _load_object(path):
    candidate = pathlib.Path(path)
    try:
        value = json.loads(
            _read_private_file(candidate, "evidence file").decode("utf-8"),
            object_pairs_hook=_object,
            parse_constant=lambda value: (_ for _ in ()).throw(
                EvidenceError(f"invalid JSON constant: {value}")
            ),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise EvidenceError(f"invalid JSON: {candidate.name}") from error
    if not isinstance(value, dict):
        raise EvidenceError(f"JSON root must be an object: {candidate.name}")
    return value


def _identifier(value, field):
    if not isinstance(value, str):
        raise EvidenceError(f"missing {field}")
    try:
        return uuid.UUID(value)
    except ValueError as error:
        raise EvidenceError(f"invalid {field}") from error


def _sha256_file(path):
    candidate = pathlib.Path(path)
    digest = hashlib.sha256()
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(candidate, flags)
    except OSError as error:
        raise EvidenceError(f"unsafe submitted artifact: {candidate.name}") from error
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise EvidenceError(f"unsafe submitted artifact: {candidate.name}")
        with os.fdopen(descriptor, "rb", closefd=False) as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    finally:
        os.close(descriptor)
    return digest.hexdigest()


def _expected_shas(artifact, expected_sha_file):
    if artifact is None and expected_sha_file is None:
        raise EvidenceError("provide at least one artifact hash source")
    expected = []
    if artifact is not None:
        expected.append(_sha256_file(artifact))
    if expected_sha_file is not None:
        try:
            encoded = _read_private_file(
                expected_sha_file, "submitted-artifact digest"
            ).decode("ascii")
        except UnicodeDecodeError as error:
            raise EvidenceError(
                "submitted-artifact digest is not canonical SHA-256"
            ) from error
        value = encoded.removesuffix("\n")
        if (
            encoded != f"{value}\n"
            or len(value) != 64
            or any(character not in "0123456789abcdef" for character in value)
        ):
            raise EvidenceError(
                "submitted-artifact digest is not canonical SHA-256"
            )
        expected.append(value)
    if len(set(expected)) != 1:
        raise EvidenceError("submitted artifact and sealed digest do not match")
    return expected[0]


def validate(submission_path, log_path, artifact=None, expected_sha_file=None):
    submission = _load_object(submission_path)
    log = _load_object(log_path)
    submission_id = _identifier(submission.get("id"), "submission id")
    log_id = _identifier(log.get("jobId"), "log jobId")
    if submission_id != log_id:
        raise EvidenceError("notarization log belongs to another submission")
    status = submission.get("status")
    if not isinstance(status, str) or status != log.get("status"):
        raise EvidenceError("notarization statuses do not match")
    if status != "Accepted":
        raise EvidenceError("notarization status is not Accepted")
    log_sha = log.get("sha256")
    if not isinstance(log_sha, str):
        raise EvidenceError("notarization log has no artifact SHA-256")
    log_sha = log_sha.lower()
    if len(log_sha) != 64 or any(character not in "0123456789abcdef" for character in log_sha):
        raise EvidenceError("notarization artifact SHA-256 is invalid")
    if log_sha != _expected_shas(artifact, expected_sha_file):
        raise EvidenceError("notarization log does not match the submitted artifact")
    return log_sha


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("submission")
    parser.add_argument("log")
    parser.add_argument("--artifact")
    parser.add_argument("--expected-sha-file")
    arguments = parser.parse_args()
    try:
        print(
            validate(
                arguments.submission,
                arguments.log,
                artifact=arguments.artifact,
                expected_sha_file=arguments.expected_sha_file,
            )
        )
    except (EvidenceError, OSError) as error:
        parser.exit(1, f"notarization evidence invalid: {error}\n")


if __name__ == "__main__":
    main()
