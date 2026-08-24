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

Release-ready evaluation also requires a strict human-review sidecar bound to the deterministic hash
of the exact trusted report's canonical compact JSON, manifest, corpus-ordered attempt identities, and
review-policy revision. This canonical binding SHA is intentionally distinct from the SHA of the
pretty-printed report file; qualification evidence records both names and values explicitly.
Coverage is derived from the trusted manifest and report, never declared by the sidecar. Each blind
review entry contains only a domain-separated opaque item ID and pass/fail verdict. Two different
public-key-derived opaque reviewer IDs, Ed25519 keys, reviewer roles, qualification-declaration
hashes, and independence-declaration hashes must sign complete matching coverage. Their complete
identities must match a canonical v2 reviewer registry signed by a source-pinned Ed25519 root.
Caller-supplied registry paths and hashes are file identities only and never trust anchors. The
production root set is empty until real independent governance is provisioned, so the production
registry decoder fails closed. Registry administration must map each actual reviewer to one current
key and enforce reviewer independence out of band. The five semantic axes are fidelity,
completeness, naturalness, theology, and proper names. Existing machine
`humanReviewRequired` results and backend quality warnings are included without changing their raw
counts.

The frozen-report workflow emits a private review packet only after the report and postflight have
been written and verified. The packet contains the opaque item IDs and the source, target, reference,
axis or check needed for blind review. It is not a release authority. Its canonical raw SHA and the
root-signed registry SHA are embedded in the v2 settlement and in both reviewers' Ed25519 signing
payloads, so changing any displayed source, target, reference, axis, subject, or resolvability field
invalidates adjudication while the settlement itself still contains only opaque IDs and verdicts.

Formal adjudication additionally requires a root-signed canonical freeze statement. It binds the
exact report file, canonical report, full attempt contents, postflight, review packet, provider,
environment, and execution provenance. Signature verification returns a non-forgeable
`TranslationVerifiedFreeze` capability; only that capability can create a
`TranslationAttestedReleaseExpectation`, and the formal release-gate API accepts that attested type.
The unsigned freeze request produced after qualification is review input for an independently
protected signer, never release evidence by itself.

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
zero outstanding or failed human-review items, a valid two-reviewer v2 sidecar, a root-signed v2
reviewer registry, the exact reconstructed review packet, and an externally attested freeze
expectation. Missing/extra/duplicate opaque items, unknown fields, duplicate or noncanonical JSON,
reviewer/key/role reuse, signature or binding drift, packet or registry substitution, reviewer
disagreement, and any fail verdict all fail closed. The gate accepts sidecar bytes only through the
duplicate-key-checking strict decoder.
Human review cannot override provider failures, release-check failures, protocol
residuals, source echo, refusal/meta text, unexpected source script, or unknown backend warnings. The
older hard-gate result and release evaluation without an expectation or sidecar remain diagnostics.

## Tests

`TranslationQualificationSupportTests` uses synthetic, non-sermon fixtures for strict shape, hash,
immutability, denominator, completion state, context, release gates, preservation, pronoun, and private
atomic-output/symlink behavior. `Scripts/check_private_qa_boundaries.sh` fails if known private-QA roots
are tracked or cease to be ignored.
