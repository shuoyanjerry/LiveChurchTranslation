# TranslationQualificationSupport

## Purpose

Provider-neutral, private-QA-only decoding, provenance verification, preservation checks, and report
construction for the bilingual Mandarin sermon qualification corpus. Corpus text is never embedded in
this target or in the release bundle.

## Public API

`TranslationQualificationCorpusLoader` verifies an explicitly pinned manifest and schema plus every
local source, reference, extracted-text, candidate, and generator hash. The preservation and pronoun
evaluators produce auditable guard results. `TranslationQualificationReportBuilder` rejects reordered,
missing, mutated, completion-invalid, or context-invalid attempts. It allows source correction only at
an evidence-bound singular-pronoun scalar. `TranslationQualificationReleaseGate` separates provider and
machine-check failures from explicit human-review work. Schema-v2 reports also bind the canonical
workspace source bundle, actual release test executable, model, helper, complete runtime bundle,
configuration, manifest, corpus schema, and corpus-ordered attempt identities. Release evaluation and
writing require a non-serialized `TranslationReleaseExpectation` made from independently
trusted corpus, provider, environment, execution provenance, and in-memory attempts. The gate rebuilds
the report from those inputs before comparison. A decoded report by itself is diagnostic-only and can
never be release-ready or accepted by the writer. Historical schema-v1 reports likewise remain
diagnostic-only. The writer uses directory file descriptors at the canonical workspace path
`.artifacts/translation-qualification`, with no-follow, mode-0600, fsync, and atomic no-replace
guarantees.

## Dependencies

Foundation and CryptoKit only. The module does not import a translation provider, discourse resolver,
glossary implementation, UI framework, persistence implementation, or model SDK.

## Threading Model

All values are immutable and `Sendable`; utilities are stateless. Callers own sequencing and model
actor isolation.

## Failure Modes

Loading fails closed on JSON shape drift, schema/corpus identity drift, unsafe paths, hash mismatch,
invalid ta degradation, broken occurrence offsets, or inconsistent counts. Report construction fails
on omissions, reordered segments, unapproved source mutation, invalid completion transitions, unsafe
failure codes, or context not derived from the latest two validator-approved persisted simulations.
Human references are interpretive review aids and never exact-match or BLEU release gates.
Release-ready evaluation additionally requires complete v2 provenance, zero provider/check failures,
zero outstanding human-review items, and an independently trusted release expectation. The older
hard-gate result and release evaluation without an expectation remain machine diagnostics.

## Tests

`TranslationQualificationSupportTests` uses synthetic, non-sermon fixtures for strict shape, hash,
immutability, denominator, completion state, context, release gates, preservation, pronoun, and private
atomic-output/symlink behavior. `Scripts/check_private_qa_boundaries.sh` fails if known private-QA roots
are tracked or cease to be ignored.
