# Ephemeral private Scripture qualification

This lane preflights a tester-provided bilingual reading corpus for one local test run. It
never downloads, scrapes, supplies, or commits Bible text or narration. The prepared
source stays outside the workspace. Its temporary working copy is deleted after success,
failure, `HUP`, `INT`, or `TERM`.

Passing preflight means only that declared edition metadata, source attribution, use
declarations, and source files are present, private, and hash-bound. A self-declaration is
not publisher authorization, proof of source authenticity, or a legal conclusion. The
tester remains responsible for having a lawful source and permitted local evaluation use.

The tool does not fetch from ESV.org, YouVersion, API.Bible, or publisher APIs. In
particular, an ESV-to-Chinese exact-verse result must not be described as compliant,
published, or redistributed without the rights holder's explicit permission. The local
lane emits metadata counts and aggregate metrics only; it does not place source text in a
report field.

## Fixed edition identity

Schema V2 accepts only the complete `ScriptureEditionPair.production` value:

- `esv-2025`: *The Holy Bible, English Standard Version®*, `ESV Text Edition: 2025`;
- `cunpss-shen-1988-zh-Hans`: `新标点和合本，神版`, 1988 Simplified Chinese,
  official online identifier `CUNP1s`.

`terminologyBaseline` guides book names and terms but never labels generated prose as an
exact quotation. `exactQuotation` requires an edition-pinned, hash-verified local source.
Exact Chinese reference comparison preserves the supplied glyphs, including `他` or `祂`.

## Prepared source

Prepare the corpus outside this repository. Names are illustrative; manifest paths are
relative to the prepared root.

```text
manifest.json
declarations/english-source-and-use.txt
declarations/chinese-source-and-use.txt
audio/<one file per item>
reference/<one UTF-8 file per item>
```

The runner rejects a source inside or containing the workspace, symlinks, special files,
empty files, traversal, files outside the temporary root, hash drift, and oversized files.
In the temporary copy every directory is mode `0700` and every file is mode `0600`.

## Manifest V2

The top-level keys are `schemaVersion`, `corpusID`, `createdAt`, `visibility`,
`mustNotCommit`, `editionPair`, `sourceDeclarations`, `items`, and `translationPairs`.
Unknown and duplicate JSON keys are rejected. The fixed fields include:

```json
{
  "schemaVersion": 2,
  "visibility": "gitignored-private-local-qa-only",
  "mustNotCommit": true
}
```

Generate the full encoded edition pair with the public Swift models so any identity field
drift fails closed.

Each `sourceDeclarations` entry contains:

```text
id
editionID
sourceAttribution
declaredBy
declarationPath
declarationSHA256
declaredAt
permittedUses
```

`declaredBy` may name an individual or a project. No church, legal-entity, commercial,
territory, or contract-registration field is required. The hashed declaration records the
tester-provided source provenance and intended local use; it does not turn that assertion
into third-party authorization.

The required `permittedUses` Boolean fields are:

```text
textEvaluationAllowed
audioEvaluationAllowed
recordingEvaluationAllowed
asrEvaluationAllowed
crossLanguageEvaluationAllowed
modelAdjustmentAllowed
modelTrainingAllowed
redistributionAllowed
```

Items independently reference `textDeclarationID` and `audioDeclarationID`. The relevant
declarations must allow text/cross-language evaluation and audio/recording/ASR evaluation.
`modelAdjustmentAllowed` must be `true` for non-weight adjustments such as hotwords,
prompts, glossaries, decoding, or thresholds. It never means fine-tuning or weight updates.
`modelTrainingAllowed` and `redistributionAllowed` must both be `false`; the validator
rejects the corpus otherwise. The user's ownership/permission statement may be the hashed
local declaration evidence, but it is not presented as publisher endorsement.

Every item carries audio/reference SHA-256 values, exact language and edition IDs, a
canonical OSIS book ID, verse range, speaker/environment metadata, `readingKind`
(`fullVerse`, `partialVerse`, or `referenceOnly`), and `partition`. Translation pairs must
align passage, reading kind, and partition. Every item belongs to exactly one pair. Both
`development` and `sealedBlindQualification` partitions are mandatory.

## One-shot preflight and cleanup

After freezing `manifest.json`, obtain its SHA-256 independently and keep it outside the
corpus. Run:

```bash
Scripts/run_ephemeral_scripture_qualification.sh \
  /absolute/path/to/prepared-corpus \
  scripture-local-test \
  <independently-recorded-64-character-manifest-sha256>
```

The runner creates a `mktemp` tree shaped as
`.artifacts/scripture-qualification/<corpus-id>`, copies the prepared source, applies
owner-only permissions, and invokes `scripture-qualification-tool verify`. It traps normal
exit and termination signals and removes the complete temporary base. It never imports a
corpus into the workspace and never deletes the tester's original prepared source.

To run a real qualification command after preflight, append `--` and the executable plus
its arguments:

```bash
Scripts/run_ephemeral_scripture_qualification.sh \
  /absolute/path/to/prepared-corpus \
  scripture-local-test \
  <independently-recorded-64-character-manifest-sha256> \
  -- swift test --filter ScriptureModelQualificationTests
```

The child receives these process-scoped environment values:

```text
SCRIPTURE_QUALIFICATION_ROOT
SCRIPTURE_QUALIFICATION_MANIFEST
SCRIPTURE_QUALIFICATION_MANIFEST_SHA256
SCRIPTURE_QUALIFICATION_AGGREGATE_ONLY=1
```

The child must load only from the verified temporary URLs. Its logs and reports may contain
item IDs, source hashes, aggregate edit counts, rates, timings, and error-code counts. They
must not contain reference text, model hypotheses, declaration contents, or private paths.
Any nonzero child exit is preserved after cleanup.

The verified loader exposes audio/reference URLs only while the temporary run is active.
Safe source-identity evidence contains IDs, verse metadata, partitions, and hashes—not
reference text. `ScripturePunctuationFidelityMetric` independently compares Unicode
punctuation and lexical position and returns counts and rates only.

Preflight does not decode audio, compare narration with reference text, authenticate a
publisher master, or produce ASR/translation quality results. Those require a separate
aggregate-only qualification runner using the same ephemeral lifecycle.
