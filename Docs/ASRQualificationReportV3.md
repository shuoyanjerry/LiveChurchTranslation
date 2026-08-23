# ASR Qualification Report V3

## Public API

`ASRQualificationReportV3Builder.build` accepts one validated Manifest V2,
its canonical lowercase SHA-256, provider and environment metadata, and one
`ASRQualificationClipEvaluationInputV3` per frozen manifest clip. It returns an
immutable, directly `JSONEncoder`-encodable `ASRQualificationReportV3` whose
`schemaVersion` is always `3`.

An evaluation input repeats the exact manifest segment definitions and supplies
one ordered `ASRQualificationAttemptV3` per segment. Edge-insertion policy is not
an evaluation input: the report copies the sole frozen source of truth,
`ASRQualificationClipV2.allowsHypothesisEdgeInsertions`.

## Validation and Failures

Construction is fail-closed with typed `ASRQualificationReportV3Error` values.
The builder validates the manifest, manifest-hash shape, metadata, exact clip
set, exact segment definitions, manifest-derived source duration, raw UTF-8
reference SHA, and attempt count/order/input sample count/PCM hash. Elapsed time
must be finite and nonnegative. A success has a hypothesis and no failure code;
a failure has no hypothesis and a nonblank failure code. `failureCode` is a
stable, redacted machine code; callers must not place raw or localized error
messages, paths, user text, or other sensitive details in it.

The caller supplies the manifest SHA because only the caller owns the original
manifest bytes. The builder validates its canonical form but cannot prove that a
hash string belongs to a typed manifest reconstructed independently of those
bytes.

## Metrics and Timing

Successful hypotheses are joined in manifest sequence order with a newline;
normalization removes that separator. Every clip and the aggregate contains
strict CER, optional edge-free semiglobal CER, and strict full-character-aligned
pronoun confusion. Aggregate CER is computed from summed edit and reference
counts. The optional aggregate edge-free metric exists only when every clip's
frozen policy permits edge insertions; mixed-policy and all-strict corpora return
`nil`, avoiding an unlabeled subset rate. Pronoun pair counts and all totals are
summed; rates are never averaged.

`sourceAudioSeconds` is the whole source duration. `decodedInputSeconds` includes
every frozen model-input sample, overlap, padding, and failed attempt.
`unionCoveredSourceSeconds` unions source intervals and excludes padding.
`decodeSeconds` and the RTF numerator include every success and failure; RTF is
`decodeSeconds / decodedInputSeconds`. The within-three-seconds numerator counts
only successful attempts at or below three seconds, while all attempts remain in
the denominator. Successful-attempt percentiles are `nil` with no successes.
P50/P95 otherwise use sorted index `ceil((count - 1) * percentile)`.

## Complexity

Validation, interval union, timings, and aggregation are linear outside text
alignment. CER and pronoun alignment require `O(r * h)` time and space per clip,
where `r` and `h` are normalized reference and hypothesis lengths. Report memory
also retains attempts and the generated hypothesis text for auditability.
