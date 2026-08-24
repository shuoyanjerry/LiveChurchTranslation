# HyMT2 qualification tests

The qualification harness keeps two glossary roles separate:

- provider prompt entries continue to come only from production `DefaultGlossary`;
- manifest theology evidence comes from the tracked, test-only, exact-label
  `HyMTQualificationTheologyCatalog`.

The frozen manifest v1 vocabulary has 30 explicit labels. Every label is hard-required and
has an explicit preferred English target plus a conservative, ordered list of accepted
surface forms. Simplified and traditional labels, and `事奉` / `侍奉`, have separate records.
Catalog lookup never infers a record from an alias or substring. The stable policy ID and
SHA-256 bind the label, preferred target, ordered accepted targets, and required flag.

A surface-form pass only proves that an allowed complete English word or contiguous phrase
appeared. It is not a semantic-quality oracle. A semantically valid rendering outside the
conservative list is left as a hard failure for human review instead of being made to pass
through a broad synonym.

## Provenance-complete private replay

Use `Scripts/run_hymt_bilingual_qualification.sh`; direct model-bearing `swift test` invocation is not
a supported evidence path. The driver checks private-data permissions and a fresh report filename
before building. It performs two release build/bootstrap rounds and requires identical canonical
source-bundle and actual test-executable SHA-256 values before invoking the private test with
`--skip-build`.

The harness rehashes source, test executable, model, helper, all ten sibling llama.cpp dylibs, license,
runtime marker, provider configuration, manifest, schema, and corpus files after inference and before
and after both the release gate and report write. The driver then runs a no-inference postflight in the
same release test executable, even when the quality gate fails. Postflight decodes the actual schema-v2
report, rebuilds it from the frozen corpus, and requires exact equality with the execution guard's newly
hashed provenance. Only then does it atomically create `<report>.postflight.json` with mode `0600`.
The fixed sidecar contains only the report and input SHA-256 values, an ISO-8601 timestamp, schema
version, and `postflightVerified: true`; it contains no transcript text, local path, or error detail.
An existing report or sidecar, missing or malformed report, or any persistent drift fails closed. Reports
contain only hashes, counts, revisions, and settings for these identities—never local model, helper,
corpus, or workspace paths. Existing output evidence is never overwritten. A quality-gate failure
preserves the report as a diagnostic artifact. The freeze phase never has formal release authority;
only the separately root-attested adjudication path can print `RELEASE_READY=true`.

### Two-phase blind-review workflow

The default invocation is the freeze phase. It never reads a reviewer registry or review settlement:

```sh
HYMT_MODEL_DIR=/absolute/model \
HYMT_LLAMA_SERVER=/absolute/llama-server \
BILINGUAL_TRANSLATION_MANIFEST=/absolute/private-manifest.json \
BILINGUAL_TRANSLATION_REPORT=exact-run.json \
Scripts/run_hymt_bilingual_qualification.sh
```

Even when the initial no-review gate returns nonzero, a successful postflight leaves four new,
mode-0600, no-overwrite files: the exact report, `<report>.postflight.json`, the review packet
named by `BILINGUAL_TRANSLATION_REVIEW_PACKET` or `<report-without-.json>.review-packet.json`, and
the canonical unsigned freeze request named by `BILINGUAL_TRANSLATION_FREEZE_REQUEST` or
`<report-without-.json>.freeze-request.json`.
Record the printed `REPORT_FILE_SHA256`, `CANONICAL_REPORT_BINDING_SHA256`,
`POSTFLIGHT_ATTESTATION_SHA256`, `HUMAN_REVIEW_PACKET_SHA256`, and `FREEZE_REQUEST_SHA256`. The
request contains complete file, canonical-report, full-attempt, provider, environment, and execution
provenance bindings, but it is not an attestation and cannot make a release ready.

An independently protected release authority must recompute the request from the exact trusted run
before signing it with an offline or KMS-held Ed25519 key. The private key must never enter this
repository, the candidate workspace, environment variables, or a job that executes changeable
candidate code. Only the public key and active policy revision are compiled into the formal verifier.
The production authority set is intentionally empty until that governance is provisioned, so formal
adjudication currently fails closed.

After two independent reviewers finish, run the adjudication phase against the unchanged tree and
the same model, helper, manifest, report, and postflight. It does not start the model or regenerate the
report, postflight timestamp, attempts, or latency:

```sh
TRANSLATION_QUALIFICATION_ADJUDICATE=1 \
HYMT_MODEL_DIR=/absolute/model \
HYMT_LLAMA_SERVER=/absolute/llama-server \
BILINGUAL_TRANSLATION_MANIFEST=/absolute/private-manifest.json \
BILINGUAL_TRANSLATION_REPORT=exact-run.json \
BILINGUAL_TRANSLATION_REVIEW_PACKET=exact-run.review-packet.json \
BILINGUAL_TRANSLATION_FREEZE_ATTESTATION=/absolute/root-signed-freeze.json \
BILINGUAL_TRANSLATION_REVIEWER_REGISTRY=/absolute/root-signed-registry.json \
BILINGUAL_TRANSLATION_HUMAN_REVIEW_SIDECAR=/absolute/signed-settlement.json \
Scripts/run_hymt_bilingual_qualification.sh
```

The signed freeze, registry, and settlement files must be caller-owned, regular, non-symlinked,
nonempty mode-0600 files. Their v2 schemas reject missing, unknown, duplicate, reordered, or
noncanonical JSON. The reviewer registry is accepted only when its Ed25519 root key, registry ID,
policy, and exact revision match the source-fixed production policy; a caller-supplied path or hash is
never a trust anchor. Each reviewer signature binds the exact packet SHA and root-signed registry SHA
in addition to the report, reviewer identity, complete opaque item coverage, and verdicts.

Adjudication verifies the freeze root before treating any report attempt as trusted, rehashes the
current source, executable, model, helper, runtime, manifest, schema, and configuration, rebuilds the
postflight and review packet byte-for-byte, then uses the attested-only release gate. It reopens and
rehashes the freeze, report, postflight, packet, registry, settlement, and runtime inputs after the gate;
`RELEASE_READY=true` is printed last. Legacy caller-provided report, postflight, registry, or sidecar
"trusted SHA" variables are explicitly rejected.

These repeated snapshots are not an atomic filesystem guarantee. A process already able to mutate the
model or helper paths could transiently replace same-size content after one hash, allow the helper to
open it, and restore the pinned content before the next hash. The harness cannot fully exclude that
replace-and-restore TOCTOU without a trusted immutable filesystem or equivalent host enforcement. Run
release qualification on an isolated host where untrusted processes cannot write the model or runtime
directories.
