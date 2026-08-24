# TranslationHyMT2

## Purpose

Infrastructure adapter for faithful local Mandarin-to-English and English-to-Simplified-Chinese
translation with Tencent Hy-MT2 1.8B GGUF. It owns a bundled `llama-server` child process and talks
only to its authenticated IPv4 loopback endpoint. The app user does not install llama.cpp or another
runtime.

## Public API

- `HyMT2TranslationProvider`: `TranslationProvider` implementation. Call `loadModel(at:)`, then `translate(_:)`, and finally `shutdown()`.
- `HyMT2Configuration`: immutable helper, inference, timeout, and resource limits.
- `HyMT2Error`: explicit model, helper, startup, transport, input-guard, and output-validation failures.

Each request may carry prior validator-approved `TranslationContextEntry` pairs from the current process.
The prompt includes only the two newest pairs, labels them as non-output background, and keeps the current
source in a separate delimiter. Callers remain responsible for admitting only finalized in-memory
translations; archived transcripts intentionally contain no translated text.

Each request may also carry occurrence-level `TranslationPronounGuidance`.
The protected-pronoun contract below applies only to Mandarin-source, English-target requests;
English-source requests do not receive Mandarin occurrence guidance.
Unresolved spoken *ta* is explicitly neutral even when ASR wrote `他` or `她`;
verified male/female decisions come only from the upstream evidence policy.
Verified Christian-deity identity is a separate non-biological decision. Every
guided source occurrence is first validated against the immutable UTF-16-aligned raw
`他`, `她`, or `祂` glyph. The model-visible source then supplies the audited decision
beside a request-scoped ordinal protected block whose content is a reserved sentinel
encoding that occurrence's unresolved, verified-female, verified-male, or
verified-deity decision. This never rewrites the stored Chinese transcript. The model
must copy that entire block unchanged directly after its corresponding English pronoun. Validation binds the
raw output immediately before each complete block, requires its sentinel to match
the expected resolution, and is per occurrence,
never a sentence-wide gender set: unresolved occurrences accept only singular-they
forms, female/male occurrences accept only their matching forms, and deity
pronouns accept conventional masculine forms. Protected blocks are stripped before any
text reaches the UI or later context.

Canonical protected blocks remain mandatory for every initial response. The prompt
also remains canonical-only. During the one strict retry, exact current-request
nonce-bearing blocks may use one homogeneous surface: all zero-gap canonical blocks
or all spaced canonical blocks. This remains fail-closed even when the initial output
was structurally malformed because the strict response must independently prove every
current nonce, ordinal, and resolution exactly once with no protocol residue. A
nonterminal spaced canonical occurrence has the accepted form
`ASCII_PRONOUN U+0020 EXACT_BLOCK U+0020 CONTINUATION`. The continuation must begin
with a non-whitespace, non-punctuation character. Only the last block in output may
instead end immediately at EOF or be followed immediately by one ASCII period and
EOF. No other punctuation, trailing whitespace, or trailing text is accepted for
that terminal form. A nonterminal comma form is accepted only as
`ASCII_PRONOUN U+0020 EXACT_BLOCK "," U+0020 ASCII_LETTER_CONTINUATION`. The reader
removes only the pre-block space and exact block, preserving the post-block space,
comma-space, period, or EOF. If any spaced canonical occurrence appears, every guided
occurrence must use that family and the flat reader cannot participate.

Flat certificates have the exact form `ASCII_PRONOUN Pdddd QLR_RESOLUTION`, with one
U+0020 space at each separator. Unlike nonce-bearing canonical forms, this strict-only
reader is enabled only after the initial response proved every current request nonce,
ordinal, and resolution exactly once, passed all non-pronoun fidelity checks, and
failed solely at pronoun binding or class. Zero-gap/spaced or canonical/flat hybrids,
unsafe token boundaries, unknown or residual ordinals, nonces, tags, escaped or partial
protocol text, normalized/case lookalikes, and altered resolution tokens fail closed.
Validation removes only the flat space-plus-certificate suffix, leaving the pronoun and
following punctuation or space.

Flat certificates intentionally contain an ordinal but no request nonce. The
capability is tied to the exact current plan and cannot be obtained from a replayed or
malformed initial nonce surface. However, after a valid current initial proof, a flat
strict response replayed from a different request with the same ordinal/resolution
shape is not cryptographically distinguishable. The single-retry scope and initial
nonce proof reduce that residual cross-request replay risk; they do not eliminate it.

`loadModel(at:)` accepts either a GGUF file or a directory containing `Hy-MT2-1.8B-Q4_K_M.gguf`.

## Dependencies

- `TranslationAPI` for domain requests, results, terms, and the provider protocol.
- `ModelRuntimeAPI` for the lightweight runtime-health boundary used between sessions.
- Foundation for `Process`, `URLSession`, JSON, clocks, and filesystem inspection.
- A pinned, signed `llama-server` executable must be copied into `Contents/MacOS` by release packaging. Its sandboxed child-process signature contains only App Sandbox and inheritance entitlements. No llama.cpp symbols leak into the business layer.

## Threading Model

`HyMT2TranslationProvider`, the process controller, and the HTTP transport are actors. One provider serializes model lifecycle and inference. Cross-boundary inputs are immutable `Sendable` values; no singleton or shared mutable state is used.
Its health check verifies only resident model state and whether the managed
helper process is still running. A failed check lets session preparation restart
the helper from the already verified local GGUF without hashing it again.

## Failure Modes

Missing/non-executable helper, missing/ambiguous GGUF, launch failure, early helper termination, health timeout, HTTP error, malformed JSON, and empty input are surfaced as errors. A quality warning is recorded when output loses a selected glossary term, Arabic number, negation, Scripture-reference shape, or pronoun alignment; contains model commentary; or has implausible length. Quality warnings get exactly one stricter retry. If neither attempt is validator-approved, the safest candidate with fewer warnings is still returned and marked for backend review. It remains visible to listeners but is excluded from translation context.

Before any model completion request, the current source, both fields of every
context pair, and every glossary source, target, alias, and accepted target are
checked against the exact prompt-control delimiter vocabulary. Inspection applies
NFKC, removes Unicode format characters, and recognizes case or whitespace
lookalikes. A collision fails closed as typed `invalidInput` without including the
input or matched delimiter in diagnostics. Ordinary angle-bracket text that is not
a reserved delimiter remains valid.

Invalid, overlapping, duplicate, or non-pronoun guidance ranges fail before
inference. Reserved protocol prefixes in guided source, context, or glossary data
also fail closed. Missing, duplicate, unknown, malformed, structurally unbound, or
policy-invalid target blocks enter the same single strict-retry path. Complete protocol blocks are
removed before a safe best-effort candidate is returned. Empty output, prompt-control delimiters,
or residual protocol text are never published; if neither attempt has a safe candidate, a typed
retryable `invalidOutput` keeps the source audio pending for later translation.
If both protocol-bearing attempts fail only pronoun validation, one final prompt omits
the pronoun protocol. Its safe nonempty output remains visible with backend pronoun and
fidelity warnings, while any request ordinal, including whitespace-split unknown
`Pdddd` values, remains fail-closed. Ordinary identifiers outside the exact reserved
ordinal shape remain valid.
When the initial rejection concerns the pronoun protocol, the strict retry receives
only a fixed failure code and its corresponding protected-block repair rule. Failed output,
source text, target text, marker IDs, and observed text are never replayed in that
correction section.

Every llama.cpp completion request also supplies the exact closing CURRENT SOURCE
delimiter as a generation stop sequence. The server therefore stops before returning
that prompt boundary when a model tries to echo it. This is only a generation aid:
the output validator still independently rejects opening delimiters, disguised or
residual prompt controls, and protocol fragments. Unexpected script is a backend quality
finding; an exact source echo or explicit model refusal is retained for retry because it is not a
translation.

The helper binds to `127.0.0.1` on a randomized high port with a per-launch random API key. Packaging must include the macOS network-client/server entitlements required by its sandbox policy.

## Tests

`TranslationHyMT2Tests` uses fake process and transport actors. It covers model lifecycle, readiness polling, exact single retry, glossary filtering, bounded background context, current-source delimiters and their case/NFKC/Unicode-format lookalikes, prompt rules, shutdown, termination, timeout, and each output guard without starting the real helper.
An internal, default-no-op attempt observer exposes only request ID, initial/strict phase, and
accepted/rejected/transport-failed outcome to the qualification target. It never exposes source,
target, reference, context, or prompt text and does not expand the public provider API.
An independent default-no-op pronoun trace emits only accepted request ID, phase,
source range, resolution, and realization class for private qualification; it also
contains no source, prompt, or target text.

The test target also contains an exact-opt-in private negation diagnostic. It runs only when
`HYMT_PRIVATE_NEGATION_DIAGNOSTIC=1` and all model, helper, frozen bilingual manifest,
classified-report, and output-filename variables are present. It selects only failed attempts whose
structured failure code contains the `neg` token. Corpus order and the classified report's last two
validator-approved context pairs are replayed; a diagnostic success is never admitted into later
context. Mandarin cues are classified with explicit phrase ranges plus `NLTokenizer` for standalone
`不`. Initial and strict outputs remain memory-only and are reduced to cue class, fixed validation
codes, latency, and SHA-256. Before the mode-0600 JSON is written beneath
`.artifacts/translation-qualification`, an allowlisted-shape guard scans the corpus, classified
source/reference/hypothesis/context text, and newly captured model outputs and rejects any match.
The private paths use `BILINGUAL_TRANSLATION_MANIFEST` and
`BILINGUAL_TRANSLATION_CLASSIFIED_REPORT`; the safe output filename uses
`BILINGUAL_NEGATION_DIAGNOSTIC_REPORT` relative to the qualification artifact directory.
