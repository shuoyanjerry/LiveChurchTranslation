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
preserves the report as a diagnostic artifact and prints `RELEASE_READY=false`; only a passing gate
prints `RELEASE_READY=true`.

These repeated snapshots are not an atomic filesystem guarantee. A process already able to mutate the
model or helper paths could transiently replace same-size content after one hash, allow the helper to
open it, and restore the pinned content before the next hash. The harness cannot fully exclude that
replace-and-restore TOCTOU without a trusted immutable filesystem or equivalent host enforcement. Run
release qualification on an isolated host where untrusted processes cannot write the model or runtime
directories.
