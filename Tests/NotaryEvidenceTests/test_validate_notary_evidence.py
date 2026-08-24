import hashlib
import importlib.util
import json
import os
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "Scripts" / "validate_notary_evidence.py"
SPEC = importlib.util.spec_from_file_location(
    "validate_notary_evidence", VALIDATOR
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class NotaryEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temporary.name)
        self.artifact = self.root / "candidate.dmg"
        self.artifact.write_bytes(b"release candidate")
        self.digest = hashlib.sha256(self.artifact.read_bytes()).hexdigest()
        identifier = "2efe2717-52ef-43a5-96dc-0797e4ca1041"
        self.submission = self._json("submission.json", {"id": identifier, "status": "Accepted"})
        self.log = self._json(
            "log.json",
            {"jobId": identifier.upper(), "status": "Accepted", "sha256": self.digest},
        )

    def tearDown(self):
        self.temporary.cleanup()

    def test_accepts_exact_submission_log_and_artifact(self):
        self.assertEqual(
            MODULE.validate(self.submission, self.log, artifact=self.artifact), self.digest
        )

    def test_accepts_artifact_and_matching_sealed_digest_together(self):
        digest_file = self._digest()
        self.assertEqual(
            MODULE.validate(
                self.submission,
                self.log,
                artifact=self.artifact,
                expected_sha_file=digest_file,
            ),
            self.digest,
        )

    def test_executable_cli_validates_the_complete_binding(self):
        digest_file = self._digest()
        result = subprocess.run(
            [
                VALIDATOR,
                self.submission,
                self.log,
                "--artifact",
                self.artifact,
                "--expected-sha-file",
                digest_file,
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.stdout, self.digest + "\n")

    def test_rejects_mismatched_submission(self):
        wrong = self._json(
            "wrong.json",
            {
                "jobId": "680bf475-a5f4-4675-9083-aa755d492b18",
                "status": "Accepted",
                "sha256": self.digest,
            },
        )
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(self.submission, wrong, artifact=self.artifact)

    def test_rejects_mismatched_status(self):
        wrong = self._json(
            "wrong-status.json",
            {
                "jobId": "2efe2717-52ef-43a5-96dc-0797e4ca1041",
                "status": "Invalid",
                "sha256": self.digest,
            },
        )
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(self.submission, wrong, artifact=self.artifact)

    def test_rejects_matching_nonaccepted_status(self):
        identifier = "2efe2717-52ef-43a5-96dc-0797e4ca1041"
        submission = self._json(
            "invalid-submission.json", {"id": identifier, "status": "Invalid"}
        )
        log = self._json(
            "invalid-log.json",
            {"jobId": identifier, "status": "Invalid", "sha256": self.digest},
        )
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(submission, log, artifact=self.artifact)

    def test_rejects_stale_artifact(self):
        self.artifact.write_bytes(b"changed")
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(self.submission, self.log, artifact=self.artifact)

    def test_rejects_duplicate_json_keys(self):
        duplicate = self.root / "duplicate.json"
        duplicate.write_text(
            '{"jobId":"2efe2717-52ef-43a5-96dc-0797e4ca1041",'
            '"status":"Accepted","status":"Accepted","sha256":"' + self.digest + '"}',
            encoding="utf-8",
        )
        duplicate.chmod(0o600)
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(self.submission, duplicate, artifact=self.artifact)

    def test_accepts_a_sealed_submitted_artifact_digest(self):
        digest_file = self._digest()
        self.assertEqual(
            MODULE.validate(
                self.submission,
                self.log,
                expected_sha_file=digest_file,
            ),
            self.digest,
        )

    def test_rejects_mismatch_between_artifact_and_sealed_digest(self):
        digest_file = self._digest("0" * 64)
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(
                self.submission,
                self.log,
                artifact=self.artifact,
                expected_sha_file=digest_file,
            )

    def test_rejects_log_that_differs_from_sealed_digest(self):
        digest_file = self._digest("0" * 64)
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(
                self.submission,
                self.log,
                expected_sha_file=digest_file,
            )

    def test_rejects_missing_hash_source(self):
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(self.submission, self.log)

    def test_rejects_noncanonical_digest_file(self):
        digest_file = self._digest(self.digest.upper())
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(
                self.submission,
                self.log,
                expected_sha_file=digest_file,
            )

    def test_rejects_evidence_with_group_or_world_permissions(self):
        os.chmod(self.log, 0o640)
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(self.submission, self.log, artifact=self.artifact)

    def test_rejects_nonprivate_sealed_digest(self):
        digest_file = self._digest()
        os.chmod(digest_file, 0o644)
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(
                self.submission,
                self.log,
                expected_sha_file=digest_file,
            )

    def test_rejects_symlinked_evidence(self):
        symlink = self.root / "submission-link.json"
        symlink.symlink_to(self.submission)
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(symlink, self.log, artifact=self.artifact)

    def test_rejects_symlinked_artifact(self):
        symlink = self.root / "candidate-link.dmg"
        symlink.symlink_to(self.artifact)
        with self.assertRaises(MODULE.EvidenceError):
            MODULE.validate(self.submission, self.log, artifact=symlink)

    def _json(self, name, value):
        path = self.root / name
        path.write_text(json.dumps(value), encoding="utf-8")
        path.chmod(0o600)
        return path

    def _digest(self, value=None):
        path = self.root / "submitted.sha256"
        path.write_text((value or self.digest) + "\n", encoding="ascii")
        path.chmod(0o600)
        return path


if __name__ == "__main__":
    unittest.main()
