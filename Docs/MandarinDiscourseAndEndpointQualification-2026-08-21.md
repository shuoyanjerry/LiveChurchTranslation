# Mandarin Discourse and Endpoint Qualification — 2026-08-21

## Status and decision

This is an engineering evidence report, not a production certificate. The selected live
path is a calibrated bounded policy driven by a pinned native libfvad/WebRTC classifier
plus the measured sermon energy rescue. AdaptiveEnergy remains a replaceable fallback.
Mandarin pronoun repair is deterministic, audited, and deliberately narrow. Pipecat Smart
Turn v3.2 has a native adapter but remains an offline **shadow signal**. TurnSense 1.0 has
only a private research harness. Neither semantic model is wired into the App or may close
live sermon segments.

The reason is asymmetrical risk. A late boundary costs latency; an unsafe early boundary
can remove the linguistic context needed by both ASR and translation. Likewise, abstaining
on an ambiguous pronoun is preferable to silently assigning the wrong person or deity.

## Mandarin `ta`: what attention cannot recover

Spoken Mandarin does not acoustically distinguish `他`, `她`, `它`, and often `祂`: they
share the pronunciation *tā*. This is an information limit, not an ASR attention defect.
Attention or a larger language model can use discourse evidence, but cannot recover a
gender that the audio and surrounding discourse never supplied. The published
[TaCorrect study](https://aclanthology.org/2024.lrec-main.360/) confirms both the homophone
problem and the value of semantic/rule-assisted post-processing; it does not justify an
unconditional rewrite. Work on
[context-aware translation](https://aclanthology.org/2023.emnlp-main.943/) likewise reports
that apparently sensible document-context methods often provide only modest gains.

The implemented sequence is therefore:

```text
raw Qwen text
  -> literal ASR normalization with audit
  -> DiscourseResolutionAPI
  -> glossary matching and Hy-MT2
  -> output validation
  -> durable append
  -> admit the finalized pair to the next two turns of context
```

`DiscourseResolutionCore` is pure Swift and stateless. It accepts at most the preceding
two durably appended, validator-approved turns, ordered by persisted VAD source-segment
identity rather than the dense reader ordinal. It changes only an eligible singular
sentence/clause-leading `他` or `她`. One or more qualified current-turn human anchors may
provide gender-only evidence only when they are uniform; prior human anchors can block or
force abstention but never authorize a cross-turn gender rewrite. A qualified prior deity
anchor may classify an already-written `祂`, while only qualified current-turn deity evidence
may authorize a textual deity correction. A request can change at most its first independently
verified candidate; evidence is never propagated to later sentences or clauses. It abstains
for competing anchors, mixed `他` / `她` candidate spellings, quotations, plurals, ambiguous
or unsafe deity references, lexical substrings, stale or misordered context, names,
occupations, and evidence that appears only after the candidate. Every accepted change stores
the original character, replacement, source range, reason, policy confidence, and evidence
turn. Raw ASR remains in the transcript.

Hy-MT2 receives only the same latest two finalized pairs as non-output background. Its
prompt says that spoken *tā* can be ambiguous, forbids stereotypes, and requests singular
`they` when evidence is absent. An immutable occurrence-level decision now crosses
DiscourseResolutionAPI, TranslationAPI, and TranscriptAPI: verified evidence permits
male/female human translation; unresolved spoken *tā* forbids either assignment. Verified
Christian-deity identity is a separate, non-biological state that permits the divine name
or conventional singular He/Him/His. The validator does not infer evidence from an `他` /
`她` ASR glyph. Every decision, including unchanged unresolved text, is persisted with its
UTF-16 range; raw ASR remains untouched in the audit. Prompting is defense in depth, not
the correction engine.

The earlier five-case safety-regression set remains a focused historical regression only.
It demonstrated first-candidate-only repair and quotation/speaker-shift abstention, but it is
too small to estimate coverage. Its 0.536–1.022-second Hy-MT observations also predate the
current occurrence-level protocol and are historical smoke timings, not current SLA evidence.

The current frozen bilingual policy replay contains 144 segments and 108 annotated `ta`
occurrences. Of 85 occurrences labelled resolvable by the corpus policy, the resolver made
one correct automatic resolution (1.17% coverage) and safely missed 84. It made zero wrong
automatic resolutions, produced 9/9 required abstentions, and protected 14/14 unsafe
occurrences. This establishes a deliberately safe but extremely low-coverage baseline; it
does not establish accurate or complete pronoun recovery. The exact private report SHA-256
is `992c7684fec1a299103967788549977fe3ccb49fa33e1ba35769a3544d15eb46`.

A separate hash-only taxonomy of all 84 misses found 40 quotation-protected occurrences,
38 ineligible pronoun positions, 5 additional-candidate protections, and 1 plural
protection. Fifty-seven misses depended on name continuity, but they reduced to only 12
anonymous entities. Under leave-one-entire-source-out evaluation, the local evidence
contained zero independently verified entity-and-referent-class pairs. A looser
same-string-plus-nearby-gender-marker rule made 6 automatic predictions on the full
108-occurrence red-team set: 0 were correct and all 6 were wrong. It is therefore rejected.
The only zero-error verified-entity rule available from current evidence makes no
predictions and recovers nothing. The mode-0600 feasibility artifact has SHA-256
`d8d8fe71184bc753ce74df77dad9faab14e60dda89999a36519e02cdf183e8ce` and contains no
names or sermon text. A future ontology must bind versioned canonical IDs and locale-aware
aliases to independent publisher evidence, including conflict records; corpus labels and
name stereotypes are not admissible evidence.

A sixth reviewed case from Argyle 2025 is deliberately recorded as a known coverage gap:
the official manuscript says Pharaoh's daughter entered the palace built for **her**, while
both tested Qwen paths produced `为他建的宫殿`. The passage also contains Solomon and a
direct quotation, so a gender-word replacement would be unsafe. The resolver abstains and
retains the raw source for review. These six cases are coverage evidence, not an accuracy
rate, and the unresolved object-pronoun case prevents any claim of perfect pronoun handling.

The exact local Qwen adapter was also replayed on that 12-second held-out case with no
hotwords, an antecedent term, the prior turn, and an answer-shaped term list. None of the
four variants repaired the object pronoun (0/4); the prior-turn variant also echoed prompt
text into recognition. The cold first decode took 4.051 seconds and the next three took
2.536–2.895 seconds. Therefore Qwen hotwords remain strictly a glossary channel: session
code never inserts prior utterances, translations, or gender answers. Discourse evidence
is resolved after ASR and cannot be manufactured by recognizer prompting.

## Calibrated sentence boundary policy

The boundary policy and the speech/non-speech classifier are separate injected concerns.
The timing profile analyzes 20 ms windows and applies these ordered constraints:

- retained active segments below 3.5 seconds wait for 950 ms endpoint silence;
- other ordinary completion uses 650 ms endpoint silence;
- after 9 seconds of retained active-segment age, a 500 ms pause may produce a soft boundary;
- from 15 seconds of retained age, close at the first stable 3-of-5 acoustic non-speech boundary;
- at 16.5 seconds of retained age, close at the hard cap if no safe pause appeared;
- two consecutive **raw** voiced windows cancel an endpoint pause immediately, rather
  than waiting for the five-window smoothed vote to recover.

Retained active-segment age includes up to 240 ms of pre-roll; it is not pure voiced duration.
The raw-resume rule separates speech resumption from start/noise smoothing. The bounded
15–16.5 second policy avoids the previous 27-second hard cut while preserving a grace
window for a natural pause. The live classifier is libfvad mode 2 OR the sibling project's
measured strong-energy rescue; the energy-only implementation remains available only as a
fallback. Timing and VAD still cannot distinguish sermon speech from singing with perfect
reliability. This follows the broader evidence that
semantic sentence boundaries can improve long-form ASR, while segmentation still requires
an explicit latency policy: see the
[Interspeech semantic segmentation study](https://www.isca-archive.org/interspeech_2023/huang23b_interspeech.html)
and the
[adaptive simultaneous-translation segmentation study](https://aclanthology.org/2020.emnlp-main.178/).

## Four-hour sermon endpoint replay

Four publicly accessible church recordings were replayed locally: two Argyle Road Baptist
Church Mandarin sermons and two Friendship Agape Mandarin sermons with live English
interpretation. The decoded 16 kHz mono WAV replay was 14,514.465 seconds (4 h 1 m 54 s).
No time-aligned human boundary labels were available, so these measurements describe
behavior, not boundary accuracy.

| Detector and timing profile | Segments | Under 2 s | Hard-cap proxy | Preferred boundary |
| --- | ---: | ---: | ---: | ---: |
| **Selected** mode 2 hybrid + stable boundary | 1,064 | 2.82% (30) | 34.40% (366) | 288 |
| Mode 2 hybrid + 500 ms wait after 15 s | 1,043 | 2.78% (29) | 58.49% (610) | 47 |
| Mode 3 hybrid + identical stable FSM | 1,531 | 9.80% (150) | 4.11% (63) | 171 |
| AdaptiveEnergy fallback + calibrated timing | 1,390 | 7.55% (105) | 10.58% (147) | 192 |

The current counts include preservation of a confirmed short tail after a 16.5-second
split. Requiring a 500 ms post-15-second wait reduced the total by 21 segments but increased
the hard-cap proxy by 244. Mode 3 reduced the hard-cap proxy by 303,
but emitted 467 more segments and raised the short-segment rate by 3.48 times. It therefore
remains a structural challenger, not a promoted classifier. The selected mode 2 stable
profile remains the live default.

`Hard-cap proxy` means only that `.maximumDuration` closed the segment. It is not a known
mid-word cut, an unsafe-boundary label, or an accuracy rate. Likewise, under-two-second
counts and boundary reasons are behavioral measurements. Human time-aligned labels are
required to decide whether any of these structural changes are safer.

The selected mode 2 profile was also replayed over an expanded local set of 14 WAV files:
27,524.215 seconds (7.6456 hours), 2,321 segments, 156 under two seconds (6.72%), 584
hard-cap proxies (25.16%), 480 preferred boundaries, 461 soft pauses, 791 trailing-silence
closures, and five end-of-stream closures. Segment duration was 13.32 seconds at p50 and
16.5 seconds at p95/p99. The run had no manual labels, and its detector throughput was
contaminated by a concurrent model job, so it contributes structural coverage only.

The passive candidate-pause companion replayed those same 14 files and 27,524.215375
seconds without changing the 2,321 production boundaries. Its schema-v2 report contains
4,596 pause episodes; 4,596 reached 250 ms, 4,044 reached 300 ms, and 2,954 reached 400 ms.
At 250 ms, all 4,596 episodes resolved: 3,304 by `speechResumed`, and 2 at end of stream,
38 at maximum boundary, 461 at soft silence, and 791 at trailing silence by
`segmentEnded`. Two independent A/B writes were byte-identical at SHA-256
`b7269f437ef9500329d02eb9bf63713a59e965a03addb05aa56617eed5aa45e5`.
The source-bound provenance covers the exact 59-file production VAD source set and the
exact 41-file companion harness/validator/writer source set; an independent red-team
validation found zero invariant failures.

`speechResumed` is an acoustic continuation proxy, not a human unsafe-boundary label. An
episode's final reason is the later production-segment outcome associated with that
episode, so final-reason counts are episode-weighted, future associations rather than
independent boundary totals. Candidate threshold crossing and frame-level observation lag
are not capture-to-reader end-to-end latency. No threshold or candidate endpoint may be
promoted without blinded human complete/incomplete and unsafe-cut labels.

A deterministic blind-review packet now exposes 84 public-domain Scripture boundary
events, but it contains 0 human labels. Its packet aggregate, sealed provenance, and
attestation SHA-256 values are respectively
`389e19f71a080af50f320eaccb51f6fd0f8004da02cf9f395dc85290a6f04b39`,
`6e0990be715cc47ab57b36a481463a7b181b66dd67d3ba0346d63d30cce5950b`, and
`922d98c20fa121c67354a9fb055eb17a4034585f871d8bb75454a2a9211723df`.
This is reviewer-workflow calibration, not the required genuine-sermon release set, and
its unlabeled items supply no endpoint-accuracy claim.

### Expanded v3 selected-WebRTC baseline

The manifest-aware selected-WebRTC baseline has now replayed the normalized v3 media. Its
authoritative A/B reports are
`.artifacts/v3-selected-vad/v3-selected-webrtc-exact-tree-{a,b}-2026-08-22.json`.
Each is 238,691 bytes, mode `0600` under a mode-`0700` directory; they are byte-identical
with SHA-256
`7060fcd3baed4d53e51fe64a3c1e677ff02a66e121fe402abbaafddda5b62ed8`.
They bind Package.swift SHA-256
`a4f2cbafa2914deaf7a754d8c18d1fc9dce674bb9fe42d2658feb75b639cbe4e`,
Package.resolved SHA-256
`1b40df984c85f9f799c558e6783ce81daed1024e3d27bf3f7a6bac342a7cf816`,
the unchanged 59-file production VAD bundle, the 42-file qualification harness, and the
actual loaded Release test executable.
All 128/128 WAV-track attempts succeeded, 0 failed, and all 128 passed parity. Across 14
logical items and 658,970,377 PCM sample frames (41,185.6485625 seconds), the selected
policy emitted 3,728 segments, including 193 under two seconds and 695 `.maximumDuration`
hard-cut proxies. Candidate reach counts at 250/300/400 ms were 7,742/6,970/5,383.

The genuine-sermon stratum is only 8 logical sermons/8 tracks: 425,077,013 frames,
26,567.3133125 seconds (7.379809253 hours), and 2,225 segments. The separate scripted or
narrated stratum is 6 logical programs/120 tracks: 233,893,364 frames, 14,618.33525 seconds
(4.060648681 hours), and 1,503 segments. Those 120 tracks never count toward the genuine-
sermon release gate. Eight remains below 12 sermons, and 7.379809253 hours remains below
eight hours.

Independent red-team review found zero P0/P1 findings; canonical encoding, privacy,
provenance, and every per-WAV join passed. Its only P2 note is JSON `Double` tail rendering
of approximately 2–4e-12 seconds in two subgroup fields. Integer PCM frames divided by
16,000 are authoritative. The final-v1 A/B pair is non-authoritative because separate
XCTest relinks drifted executable provenance. Final-v2 is superseded by the exact-tree pair
because package provenance changed; its attempts, aggregates, release gate, and caveats are
otherwise byte-identical to the current behavioral payload.

This is shadow structural evidence with `decisionAuthority=none`, 0 human labels, and
`accuracyEligible=false`. Its integrity gate is **GO**, but endpoint accuracy and release
remain **NO-GO**. It is a selected-WebRTC replay, not evidence for a semantic endpoint
model.

One 4,104.99-second expanded-set sermon produced 567 segments, including 110 under two
seconds. A time-stratified review of 29 short segments found 19 readable-complete proxies,
two clearly incomplete subordinate-phrase proxies, seven ambiguous short utterances, and
one near-silent end-of-stream tail. Qwen produced usable text for 28; the input guard
rejected the silent tail. None was a hard-cap closure. Acoustic review found no observed
mid-word evidence in 27, one indeterminate tail, and one non-applicable silent EOF case.
This small proxy review does not justify rolling back the acoustic baseline, but the two
semantically incomplete cases also prevent promoting acoustic silence as a safe sentence
boundary.

The native adapter vendors unmodified libfvad at commit
[`532ab666c20d3cfda38bca63abbb0f152706c369`](https://github.com/dpirch/libfvad/tree/532ab666c20d3cfda38bca63abbb0f152706c369)
under BSD-3-Clause plus its patent grant. Its C sources compile as C11 with all common
warnings promoted to errors. On the four recordings, 725,722 individual 20 ms frames were
compared against the sibling project's pinned WebRTC VAD implementation: both marked
642,571 frames voiced, with **zero frame mismatches**. This proves parity only for those
native binary frame decisions; it does not prove parity for the strong-energy rescue, the
complete hybrid classifier, the boundary state machine, or semantic boundary accuracy.
Aggregate segment counts still require a locked, manually labelled set before
production-quality claims.

## Smart Turn experiment retired

The isolated Pipecat Smart Turn v3.2 adapter never entered the App or acquired boundary
authority. Its final source-bound 400 ms shadow completed all 2,954 candidate analyses, but
the model barely separated the two native acoustic continuation proxies: common-language
ordering was 0.512348444, fixed-threshold proxy balanced accuracy ranged from 0.501443 to
0.512780, and the optimistic in-sample best was only 0.515019. The denominator contained
zero human complete/incomplete or unsafe-cut labels, so these numbers are not endpoint
accuracy; they are nevertheless insufficient evidence to justify the adapter's code,
runtime bridge, model, and qualification cost.

On 2026-08-22 the Smart Turn implementation, model, dedicated tests, shadow reports, and
unlabelled score-stratified 240-item packet were removed. The App continues to use the
selected WebRTC VAD and unchanged native boundary state machine. Model-neutral candidate-
pause traces, the 128-track selected-WebRTC v3 baseline, and the separate 84-item blind
review workflow remain available. Reintroducing any semantic endpoint model requires a new
model-neutral, human-labelled release corpus; the removed proxy thresholds are not reusable.

## TurnSense 1.0: research-only external shadow

TurnSense was evaluated only through a gitignored private Python/ONNX harness that mirrors
the upstream 16 kHz Fbank, LFR, and CMVN front end. It has no Swift production adapter and
is not linked into live VAD. The pinned 52,211,266-byte INT8 model used revision
`92924ae57f61b59cc6195d1367f8c705b2ba06b4`, upstream commit
`e1ae083a361182614f15eff5c293dadb07314ec4`, and SHA-256
`9ffa8fd0bb423986065afdedcb822fc957bb0794bcb6023c94575d8d82dd8e92`.

All 1,064 selected-policy boundaries produced normalized three-class outputs. Argmax counts
were 244 complete (22.93%), 271 incomplete (25.47%), and 549 invalid (51.60%). Per-recording
invalid rates ranged from 0.94% to 70.03%, a large cross-recording output-distribution
variation consistent with possible domain mismatch. Hard-cap boundaries were
9.84% complete, 34.70% incomplete, and 55.46% invalid; preferred boundaries were
29.86%/25.00%/45.14%. A clean single-thread M1 Pro run measured combined front end plus
inference at 90.50/94.00/112.17 ms p50/p95/p99, with about 239.9 MB process peak RSS.

There are no manual sermon completion labels, so the three classes are not accuracy and
`invalid` must never mean “discard this audio.” Upstream does not publish sufficient
training/deduplication material to evaluate leakage, and its README describes additional
license restrictions that are absent from the included Apache-2.0 license text. TurnSense
therefore remains research-only pending rights clarification, a native adapter, and a
locked labelled evaluation. It is not a release dependency or live shadow module.

## Current Swift Qwen qualification and legacy replay

The current exact Swift adapter was evaluated through the frozen public-domain Scripture
Manifest V2 and Report V3. Six clips supplied 220 exact PCM ranges and 2,589.9 seconds to the
recognizer; every attempt succeeded and every range/hash was revalidated. With the selected
four-thread profile, edge-free semi-global CER was 295/8,160 (3.6152%), strict CER was
813/8,160 (9.9632%), p50/p95 decode was 2.005/3.177 seconds, 94.55% finished within three
seconds, and RTF was 0.15800. This is public-domain Scripture component evidence—not sermon
CER, live pipeline latency, or a claim that all female `ta` glyphs are recoverable. The
Report V3 SHA-256 is
`db936183c0f5d082760f6840de1c43e1fbce8eb981d570b7c10a2100243eb17c`.

### Legacy sibling-project fifty-minute exploratory replay

The sibling project previously decoded six clips totaling 3,000.0 seconds. Its segments,
runtime path, and harness differ from the current Swift Manifest V2 qualification, so these
numbers are retained only for historical throughput and failure discovery:

| Source | Audio | Segments | Decode | RTF |
| --- | ---: | ---: | ---: | ---: |
| Argyle 2023 | 300 s | 21 | 73.200 s | 0.2440 |
| Argyle 2025 | 300 s | 22 | 63.000 s | 0.2100 |
| Friendship Mark | 600 s | 41 | 108.558 s | 0.1809 |
| Friendship Nancy | 600 s | 53 | 117.134 s | 0.1952 |
| **First-clip subtotal** | **1,800 s** | **137** | **361.892 s** | **0.2011** |
| Friendship mid-sermon, Mark + Nancy | 1,200 s | 84 | 241.305 s | 0.2011 |
| **Grand total** | **3,000 s** | **221** | **603.197 s** | **0.2011** |

Wall time for the first 30-minute subtotal was 363.261 seconds. The additional clips covered
Mark at 2,400–3,000 seconds and Nancy at 2,100–2,700 seconds, 42 segments each. There is no
aligned verbatim reference, so this is throughput and failure-discovery evidence, not
CER/WER evidence. The local result file is
`.artifacts/sermon-corpus/qwen-mid-sermon-results.json` and remains gitignored.

With a 13-term theological hotword prompt, ten music/non-speech segments echoed the entire
prompt. The new prompt-only repetition guard rejected 10/10. Re-decoding those ten without
hotwords produced five exact `system`/`系统` sentinels, also rejected by the new guard; the
other five contained singing, a short ordinary phrase, or garbled output and are not yet
fully classified. One middle-sermon segment then exposed a mixed case: an ordered theology
prompt prefix followed by valid recognized Chinese. The guard now recursively strips only
an ordered prefix of at least six prompted terms and preserves the remaining speech;
prompt-only output is still rejected. Hotword echo detection is necessary but insufficient.
The locked non-speech set must still determine whether a separate singing/music event gate
is needed; ordinary speech VAD does not promise to distinguish singing from speech.

## Hy-MT qualification and negation audit

The most recent frozen private bilingual schema-v2 run contains 144 attempts: 114 were
accepted by that snapshot's validators and 30 failed closed. There were 41 strict retries.
Independent recomputation found 252 hard-check failures, 346 total release-check failures,
and 266 human-review requirements. Required theology surfaces passed 51/70; functional-negation
checks passed 43/71 applicable segments. Pronoun guidance passed 24/108 occurrences, while
English pronoun policy passed 10/108, failed 91/108, and routed 7/108 to review. The nine
gold-policy unresolved occurrences all remained neutral and passed, but 84 resolvable
occurrences were safely missed rather than guessed.

The mode-0600 diagnostic report has SHA-256
`f43aa47269fa544c15a75aa8f2b8bc5e0341578b42713b0d5fdb134ec5c4bc88`. Its provenance
binds the exact source snapshot (`73b96970…95b`), Release test executable
(`b1258e81…e83b`), model, helper, 13-file runtime bundle, configuration, manifest, and
schema. Postflight revalidation passed in the recorded run, although this first schema-v2
artifact does not itself contain a durable postflight attestation. Translation latency was
1.566 seconds at p50, 7.618 seconds at p95, and 13.503 seconds maximum; 107/144 attempts
(74.31%) completed the translation call within three seconds. A sibling Q8 server was idle
but resident, so timing is descriptive only. This is not a passing release result:
accepted output still requires independent bilingual review, while each typed rejection is
a visible service interruption. The older schema-v1 classified report is retained only as
historical diagnostic evidence and must not be used for the current resolver or prompt.
Subsequent VAD-shadow and postflight-attestation source changes intentionally changed the
source-bundle digest, so this report is no longer evidence for the current working tree. The
next quiescent run must use a fresh, non-overwriting filename and produce the new mode-0600
`<report>.postflight.json` sidecar before it can be treated as current-snapshot diagnostic
evidence; a sidecar attests bytes and provenance, not quality or release readiness.

The existing negation guard is intentionally not treated as a semantic oracle. It currently
tests only whether any Mandarin cue occurs anywhere in the source and any small allowlisted
English cue occurs anywhere in the target. A deterministic public challenge now records four
known false passes—including lost additional negations and wrong scope—and fourteen known
false rejects, including A-not-A questions, double-negation constructions, lexical `不`, and
faithful lexical or positive paraphrases. Research likewise reports that cue presence does
not establish event/scope preservation and that attention-based signals correlate poorly
with negation omission; see
[Tang et al. 2021](https://aclanthology.org/2021.tacl-1.45/) and the
[NegPar corpus analysis](https://aclanthology.org/L18-1547/).

Two public Q4 occurrence-marker encodings were tested without changing production. The
English-placeholder variant passed 4/11 fixtures and the original-Chinese-cue variant 3/11;
both passed 0/1 fixtures with two occurrences and 0/1 with three occurrences. The report
contains output hashes but no output text and has SHA-256
`7e3fd8e897f0720db849c9b72b09a9022471286282783991a5dd15bc958fc07b`.
Neither marker encoding is eligible for production.

JSON-Schema constrained decoding was also tested as a public Q4 shadow. A per-load random
nonce, absent from the prompt and required as a schema constant, was returned correctly in
1.234 seconds; this demonstrates that the pinned helper enforced a non-empty schema in that
run rather than silently ignoring it. The schema arm produced the exact envelope, nonce, and
required bindings for 13/13 fixtures, and 12/13 passed the additional application structure
gate. Only 1/13 passed the independent semantic oracle, however: negation was 0/4 and pronouns
1/9. The comparison arm, which was a single strict-marker attempt rather than the complete
production provider flow, passed 3/13. The privacy-safe report SHA-256 is
`6fca3cac12f4b40ed0b1bd03d12d794519bce36af6888282fd6d132f34f24b96`.
This experiment omitted the separate zero-occurrence negation controls and used a random
nonce, so it is exploratory rather than a fully reproducible release A/B. It establishes
syntax enforcement, not preservation of scope, referents, or theological meaning. JSON
Schema therefore remains test-only; see the pinned llama.cpp
[grammar documentation](https://github.com/ggml-org/llama.cpp/blob/b10549/grammars/README.md)
and [server implementation](https://github.com/ggml-org/llama.cpp/blob/b10549/tools/server/server-common.cpp#L1085-L1096).

A separate privacy-safe replay diagnosed the 24 classified negation failures from the
144-attempt run. All 24 initial attempts and all 24 strict retries were rejected. The human
reference surface used an explicit English cue in only four segments, a lexical negative in
one, and no recognized English cue in nineteen; this does not make the references exact gold,
but it confirms that a mandatory `not`/`no`/`never` surface is an invalid general policy.
Strict retry produced no recognized explicit cue in any of the 24. The report contains only
enumerated cue/failure classes, timings, and raw-output hashes; it has SHA-256
`d148621d1cd033b322334e4b8f249155d19245bfb08c47f716bcc55c224f7618`.
These findings block both the current sentence-level negation guard as a quality claim and
the tested marker protocols as replacements. A future candidate must distinguish functional,
non-functional, lexical, and review-required cases; count occurrences; and keep scope/event
semantics as an independent human-review gate.

A deterministic Policy V2 prototype then replayed the frozen classified report without
calling a model. Across all 144 source segments it classified 72 as having no detected
functional negation, 71 as requiring review, and only one as having a narrow two-cue overt
requirement. Among the 109 outputs previously accepted by the current validator, it produced
zero structural passes: 64 had no detected functional source negation and 45 required review.
Two of those 45 were caused solely by the prototype's over-broad whole-target Unicode rule.
The report SHA-256 is
`fd344505e4e6786b937ae29a54f8325a4edb57adb4a1ca65639710604d542a8c`.
Independent adversarial review also showed that equal source/target cue counts can negate the
wrong predicate or argument, and that the prototype's lexical prefix masks miss ordinary
functional forms. Policy V2 therefore remains test-only. Its typed review routing is useful
for measurement, but neither an equal count nor an existing validator success may authorize
publication.

## Corpus provenance and rights boundary

The local QA sources were the official pages for Argyle's
[2023 Mandarin sermon with bilingual notes](https://arbc.sk.ca/2023/07/09/%e4%bb%8e%e5%a5%b4%e9%9a%b6%e5%88%b0%e5%bc%9f%e5%85%84-from-slave-to-brother/),
[2025 Mandarin sermon with English-translated notes](https://arbc.sk.ca/2025/07/13/living-by-faith-in-an-uncertain-world/),
and Friendship Agape's
[Mandarin/English sermon catalog](https://www.friendshipagape.com/sermons.php). The four
MP3 container durations were 1,490.155, 2,560.052, 4,822.632, and 5,641.752 seconds
respectively; decode/conversion removed container padding, yielding the 14,514.465-second
WAV replay above.

The cited pages make the recordings and translations publicly accessible but do not state
a permissive redistribution license. Consequently, audio, video, notes, extracted text,
and derived transcript are local temporary QA material under `.artifacts` only. They are
gitignored, excluded from App/DMG/release assets, and must never be committed or republished.
Only aggregate, non-reconstructive measurements and case counts belong in this repository.

## Release gates and known limits

Before semantic endpointing or the overall live pipeline may be called production-ready,
the exact release build must pass a manually time-aligned set of at least 12 sermons,
8 hours, and 6 speakers:

| Area | Release gate |
| --- | --- |
| Speech detector | Pinned native libfvad hybrid must pass the locked labelled set; AdaptiveEnergy remains fallback-only |
| Boundary safety | Zero mid-word cuts; unsafe early boundaries at most 0.2% |
| Responsiveness | Endpoint p95 at most 800 ms; at least 98% of final English visible within 3 s |
| Pronouns | Any wrong automatic gender/deity rewrite fails; raw text and audit retained for 100% of corrections |
| ASR input safety | Zero published hotword echoes or known non-speech sentinels; music/noise cases human reviewed |
| Translation fidelity | Zero critical additions, omissions, or changed negation, numbers, names, and Scripture references on the locked set |
| Theology | 100% required-term compliance or an explicitly accepted grammatical variant |
| Stability | 8-hour live soak with no lost transcript entries, bounded memory, and recovery verification |

Current evidence establishes component CER only on the frozen public-domain Scripture
Manifest V2. It does **not** establish sermon-domain CER/WER, perfect translation, a general
pronoun accuracy rate, semantic endpoint accuracy, an end-to-end 1–3 second SLA, or a
completed 8-hour live soak. See [Architecture](Architecture.md) for boundaries and
[Testing](Testing.md) for the full qualification matrix.
