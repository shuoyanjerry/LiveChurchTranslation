# Testing and Release Qualification

## One-command development gate

Run from the repository root:

```sh
./Scripts/check.sh
```

The command stops at the first failed phase:

1. Architecture graph, cycle, layer, singleton, naming, and 200-line Swift file checks.
2. `swift format lint --strict` using the committed configuration.
3. SwiftLint 0.65.0 in strict mode. The fallback downloader verifies the checksum-pinned
   official artifact before caching it under `.artifacts`.
4. Deterministic Python tests for the blind endpoint-human-label packet, with bytecode
   cache creation disabled.
5. Debug build and all default tests with compiler warnings promoted to errors.
6. Dead-code analysis using the mandatory deterministic scan and Periphery when installed.

GitHub Actions is configured to call the same gate. A local or CI pass is development
evidence only; it is not model-quality, soak, signing, notarization, or clean-Mac evidence.

## Automated suites

| Suite | Evidence provided |
| --- | --- |
| `AudioProcessingCoreTests` | Validation, downmixing, resampling, continuity, and reset |
| `AudioFileAVFoundationTests` | Exact PCM/interleaving checks plus bounded streaming decode of runtime-generated English and Mandarin WAV, AIFF, AIFC, CAF, AAC/ADTS, and M4A fixtures; corrupt-file, real security-scoped bookmark, cancellation, and restart behavior |
| `RecordingFileSystemTests` | PCM16 CAF validation, private active markers, atomic publication, partial repair, pre-first-frame crash cleanup, and post-publish recovery |
| `VADCoreTests` | AdaptiveEnergy fallback plus calibrated defaults, raw two-frame endpoint cancellation, soft/preferred/hard boundaries, smoothing, transient rejection, flush, and passive 250/300/400 ms candidate-pause trace parity |
| `VADWebRTCTests` | Pinned native libfvad configuration, typed input failures, lifecycle/reset, silence, strong-energy rescue, and independent instances |
| `EndpointHumanLabelPacketTests` | Deterministic 84-item blind ordering, exact source/audio hashes and ranges, sealed provenance separation, private permissions, and boundary-stop playback; no automatic labels |
| `ASRQwen3Tests` | Six-file model integrity, configuration/retry policy, silence/sentinel/prompt-echo guards, Manifest V2 PCM replay, Report V3 evidence, plus opt-in real-model qualification |
| `ASRFunASRNanoTests` | Exact six-file model verification, fixed fairness policy, silence/repetition guards, opt-in fixed-clip Qwen A/B, and shared Manifest V2/Report V3 corpus replay; legacy cumulative-time reports are invalid |
| `ASRNormalizationCoreTests` | Built-ins, editable aliases, longest precedence, non-cascading replacement, and correction audit |
| `DiscourseResolutionCoreTests` | Current-turn explicit-evidence `他` / `她` correction, limited prior-deity classification, stable source-sequence ordering, and audited abstention for competing/stale/unsafe context, quotations, plurals, names, and occupations |
| `GlossaryCoreTests` | Defaults, aliases/variants, enforcement, validation, and deterministic persistence behavior |
| `TranslationHyMT2Tests` | Prompt isolation, latest-two context cap, occurrence-level pronoun proof blocks, strict retry, prompt-control injection/output guards, helper lifecycle, timeout, and fidelity validation |
| `TranslationQualificationSupportTests` | Strict private-manifest/report decoding, duplicate-key rejection, recomputed preservation evidence, source-range pronoun traces, privacy-safe atomic output, and hard release gates |
| `ScriptureQualificationSupportTests` | 13 synthetic tests for exact ESV 2025/CUNPSS-Shen 1988 identity, independent manifest/source/evidence hashes, private containment, text/audio/recording/ASR/translation rights, one-licensee binding, development/sealed partitions, reading-kind alignment, strict JSON, and punctuation fidelity without report text |
| `TranscriptCoreTests` | Ordered lifecycle, raw/normalized source audit, append events, and compatibility decoding |
| `PersistenceFileSystemTests` | JSONL/Markdown sessions, synchronized append, loading, source audit persistence, and non-bypassable active-recording deletion guards |
| `LoggingOSLogTests` | Deterministic payload formatting plus a source policy that keeps all dynamic message and metadata text private |
| `UtteranceRecoveryFileSystemTests` | Stage/restart/complete lifecycle, cross-session ordering, bounds, tombstones, and quarantine |
| `ModelDownloadHTTPTests` | Manifest validation, hashing, exact sizes, shared disk-space preflight/reservations, atomic install, cancellation, and deduplication |
| `SessionManagementTests` | Fake-provider end-to-end pipeline, launch-time model-preparation single-flight/retry/cancellation, capture-before-model lifecycle, current-session recovery exclusion, stage-before-inference, stop draining, partial preservation, context, replay, and persistence failures |
| `LiveReaderTests` | Follow intent, unseen counts, transcript formatting, automatic model-preparation presentation, microphone guidance/refresh, sharing presentation contracts, and live-session control locking |
| `RemotePairingCoreTests` | Entropy shape, expiry, races, role enforcement, hashing, revocation, and audit redaction |
| `RemoteControlCoreTests` | Viewer denial, closed command authorization, stale revisions, concurrent races, replay, and target failure |
| `RemoteControlSessionAdapterTests` | Remote Start fail-closed policy and authorized stop-only forwarding |
| `RemoteProjectionCoreTests` | Snapshot/live barrier, revisions, late entries, bounds, slow-peer resync, and default-off switch |
| `RemoteProjectionSessionAdapterTests` | Session/entry mapping, resets, delta publication, and error redaction |
| `RemoteSharingFeatureTests` | Enable/disable, invitations, presentation state, peers, and revocation with protocol fakes |
| `RemoteDiscoveryBonjourTests` | Fixed service type and credential-free, bounded metadata |
| `RemoteWebAssetsTests` | Asset allowlist, no third-party URLs, and Safari reader security assumptions |
| `RemoteTransportNetworkTests` | Bounded HTTP/WebSocket parsing, Host/Origin policy, cookie parity, headers, viewer denial, exact Bonjour local-network policy-denial classification, and a real localhost listener/snapshot/delta smoke test |

Most tests use protocol fakes and temporary directories. The default gate does not
download model weights, use a real microphone, or launch Safari. The network suite does
open an ephemeral loopback `NWListener`; it is not a multi-device or hostile-network test.

The audio-import format suite uses `/usr/bin/say` and `/usr/bin/afconvert` at test time with
short, original phrases (`Grace and peace.` and `愿你平安。`). It commits no audio and validates
container signatures before passing each file to the production AVFoundation stream decoder.
The current macOS 15 qualification host can encode WAV, AIFF, AIFC, CAF, AAC/ADTS, and AAC/M4A,
so those formats are mandatory in the default gate. Its system converter has no MP3 encoder;
the MP3 case is visibly skipped rather than synthesized under a false extension. To rerun the
private MP3 qualification, provide a local, rights-safe file explicitly:

```sh
AUDIO_IMPORT_MP3_FIXTURE=/absolute/path/to/rights-safe.mp3 \
  swift test --filter AudioFormatQualificationTests
```

On 2026-08-22, that environment-backed lane passed with a local private-QA, rights-safe MP3 through
the production adapter. It decoded only the bounded prefix of 16 × 100 ms chunks before cancelling.
No private audio or source path was committed or copied. This qualifies the decoder/container path
only; it does not grant permission to redistribute the fixture. The gate must pass again against
the exact signed release candidate before App Store metadata or release notes claim MP3 support.
Setting the variable to a missing or invalid file fails the test.

That lane verifies container bytes and AVFoundation streaming only. Language routing is separately
proved by `EnglishTranslationModeTests` (English ASR to Simplified Chinese) and the legacy/default
Mandarin-to-English settings path; neither format decoding nor synthetic speech establishes ASR or
translation quality.

## Opt-in real-model smoke tests

Model tests run only when explicit local inputs are provided:

```sh
QWEN_MODEL_DIR=/path/to/qwen QWEN_TEST_WAV=/path/to/16k-mono.wav \
  swift test --filter Qwen3RealModelSmokeTests

QWEN_MODEL_DIR=/path/to/qwen Scripts/run_qwen_english_qualification.sh

HYMT_MODEL_DIR=/path/to/hy-mt2 HYMT_LLAMA_SERVER=/path/to/llama-server \
  swift test --filter HyMT2RealModelSmokeTests

swift run scripture-qualification-tool verify \
  /path/to/.artifacts/scripture-qualification/<corpus-id> \
  /path/to/.artifacts/scripture-qualification/<corpus-id>/manifest.json \
  <independently-reviewed-manifest-sha256>
```

The Qwen test reports raw output, normalized output, the correction audit, audio duration,
and decode duration. The Hy-MT2 test reports outputs and sentence inference durations.
These are smoke harnesses, not quality claims. Do not use measurements from the sibling
`church_translation` project, including its long-sermon run, as validation of this exact
Qwen3-ASR/Hy-MT2 app stack.

The Scripture command is a rights, identity-metadata, containment, and hash preflight. It
does not validate grant authenticity, decode the audio, prove the declared edition content,
or produce an ASR/translation quality result. See
[Private Scripture qualification](PrivateScriptureQualification.md).

The English command generates an 18-clip, six-locale synthetic theological corpus locally and
runs the production `languageCode = "en"` path, context selector, WER/CER gates, and report writer.
It remains a deterministic regression lane, not a substitute for licensed verbatim human-sermon
evidence. See [the English qualification report](Qwen3EnglishASRQualification-2026-08-22.md).

The Hy-MT2 real-model lane now includes 24 human-authored English-to-Simplified-Chinese
theological fixtures in addition to the existing Mandarin-to-English and pronoun cases. The
2026-08-22 run passed the complete set after human review rejected and corrected two earlier
keyword-only false passes. See the
[English translation qualification](EnglishTranslationQualification-2026-08-22.md); it remains a
regression lane rather than a claim of theological infallibility or a substitute for licensed,
blinded sermon review.

The historical 2026-08-21 smoke reruns recorded one 5.93-second Qwen fixture at 1.283
seconds decode and four Hy-MT2 theological fixtures at 0.461–0.864 seconds; the five-case
suite including one discourse-pronoun case completed in 4.483 seconds. Qwen corrected
`因信生义` → `因信称义`; `在圣灵里承受` remained unchanged and therefore did not qualify
成圣 recognition. An earlier run also exercised `休恩` → `救恩`. See
[the engineering snapshot](ReleaseQualification-2026-08-21.md).

The retired semantic-endpoint experiment is not part of the test matrix. Its final 2,954-
candidate shadow had no human labels and only near-chance separation of native continuation
proxies, so its adapter, model, dedicated tests, and score-stratified packet were removed.

## Observed Mandarin-sermon replay

The 2026-08-21 offline replay used four public church recordings totaling 4 h 1 m 54 s for
endpoint behavior. The selected Swift libfvad/WebRTC hybrid produced 1,064 segments with 30
under two seconds, 366 hard-cap proxies, and 288 preferred-boundary closures. Native libfvad
matched the pinned sibling WebRTC component's binary decision on all 725,722 frames; that
does not establish parity for the energy rescue or boundary state machine.

The schema-v2 passive candidate-pause companion later replayed the 14-file expanded set:
27,524.215375 seconds, 2,321 unchanged production boundaries, and 4,596 pause episodes.
Threshold reaches were 4,596 at 250 ms, 4,044 at 300 ms, and 2,954 at 400 ms. At 250 ms,
3,304 episodes resolved as `speechResumed`; production segments ended the other episodes
at end of stream (2), maximum boundary (38), soft silence (461), or trailing silence
(791). Independent A/B outputs were byte-identical at SHA-256
`b7269f437ef9500329d02eb9bf63713a59e965a03addb05aa56617eed5aa45e5`.
The provenance binds the exact 59-file production VAD set and 41-file companion
harness/validator/writer set, and independent red-team validation reported zero invariant
failures.

These are passive acoustic observations: `speechResumed` is a continuation proxy, not an
unsafe-boundary label. Final reasons associate each episode with its later segment outcome
and are therefore episode-weighted future associations, not boundary totals. Frame-level
threshold crossing is not capture-to-reader end-to-end latency. No candidate threshold is
eligible for promotion until blinded human completion and unsafe-cut labels pass the locked
release criteria.

The native candidate-pause companion remains a model-neutral shadow of the existing state
machine. It must not be interpreted as a semantic endpoint score or a release threshold.

The deterministic blind endpoint packet contains 84 public-domain Scripture events and 0
human labels. Its packet aggregate SHA-256 is
`389e19f71a080af50f320eaccb51f6fd0f8004da02cf9f395dc85290a6f04b39`; sealed provenance is
`6e0990be715cc47ab57b36a481463a7b181b66dd67d3ba0346d63d30cce5950b`; attestation is
`922d98c20fa121c67354a9fb055eb17a4034585f871d8bb75454a2a9211723df`.
It remains a generic boundary-review workflow packet, not the genuine-sermon release set.

Current Swift Qwen component evidence comes from the frozen public-domain Scripture
Manifest V2, not from the sibling project's historical 50-minute replay: 6 clips, 220/220
successful attempts, 2,589.9 seconds presented to the recognizer, edge-free CER 3.6152%,
strict CER 9.9632%, p50 2.005 s, p95 3.177 s, 94.55% within 3 seconds, and RTF 0.15800 with
the selected four-thread profile. These are component results, not sermon-domain CER or
end-to-end latency evidence.

The latest frozen discourse replay contains 144 segments and 108 `ta` occurrences. It made
1 correct automatic resolution out of 85 policy-labelled resolvable occurrences (1.17%
coverage), missed 84, made zero wrong automatic resolutions, safely abstained on 9/9, and
safely protected 14/14. This supports a safety claim with very low coverage, not accurate or
complete pronoun recovery. Exact numbers, source provenance, semantic shadow distributions,
rights policy, and limitations are recorded in
[the Mandarin discourse and endpoint report](MandarinDiscourseAndEndpointQualification-2026-08-21.md).

The four-hour sermon replay had no aligned verbatim transcript and therefore yields no
sermon CER/WER. Manifest V2 separately establishes Scripture component CER; neither run
exercised microphone capture, durable recovery, translation, and reader latency continuously
over four hours. Do not label either run semantic-boundary accuracy, a 1–3 second end-to-end
SLA, sermon-domain accuracy, or long-running qualification.

The expanded media-only replay manifest contains 14 logical spiritual-audio items and 128
independent tracks totaling 11.44046 decoded hours, with reset/EOS semantics at every track.
Only 8 items totaling 7.37981 hours are genuine church sermons; 6 items/120 tracks are
scripted or narrated programs. The normalized media therefore improves acoustic diversity
but does not satisfy the 12-sermon/8-hour release corpus contract. Its private manifest is
SHA-256 `2b5e75d3e497b08a946b64a44c7a364e98225c75fc59147ae5e31c81737548a6`;
conversion alone provides no VAD, ASR, translation, or model-quality result.

The selected-WebRTC baseline has now replayed all normalized v3 media. The authoritative
A/B reports are
`.artifacts/v3-selected-vad/v3-selected-webrtc-exact-tree-{a,b}-2026-08-22.json`;
each is 238,691 bytes and mode `0600` under a mode-`0700` directory. They are byte-identical
at SHA-256 `7060fcd3baed4d53e51fe64a3c1e677ff02a66e121fe402abbaafddda5b62ed8`.
All 128/128 track attempts succeeded, 0 failed, and parity passed 128/128. Overall coverage
is 14 logical items, 128 tracks, 658,970,377 authoritative PCM frames
(41,185.6485625 seconds), 3,728 segments, 193 under two seconds, and 695
`.maximumDuration` proxies. Candidate reach counts at 250/300/400 ms are
7,742/6,970/5,383.

The genuine stratum is 8 sermons/8 tracks, 425,077,013 frames, 26,567.3133125 seconds
(7.379809253 hours), and 2,225 segments. The scripted/narration stratum is 6 programs/120
tracks, 233,893,364 frames, 14,618.33525 seconds (4.060648681 hours), and 1,503 segments;
it never offsets the genuine-sermon gate. Independent red-team review found zero P0/P1
findings, while canonical encoding, privacy, provenance, and every per-WAV join passed. The
only P2 note is a roughly 2–4e-12-second JSON `Double` tail in two subgroup duration fields;
integer PCM frames divided by 16,000 are authoritative. Final-v1 A/B is non-authoritative
because separate XCTest relinks drifted executable provenance. Final-v2 is superseded by
the exact-tree pair because package provenance changed; its behavioral payload is
byte-identical to the current pair.

The v3 baseline is shadow-only with `decisionAuthority=none`, 0 human labels, and
`accuracyEligible=false`. Integrity is **GO**; release is **NO-GO** because 8 < 12 genuine
sermons and 7.379809253 < 8 genuine hours. No semantic endpoint model is scheduled for this
corpus until a model-neutral human-labelled gate exists.

The most recent frozen private Hy-MT schema-v2 run contains 144 attempts: 114 validator-accepted, 30
typed fail-closed, and 41 strict retries. It recorded 252 hard-check failures, 346 total
release-check failures, and 266 human-review requirements. Pronoun guidance passed 24/108
occurrences, while the English pronoun policy passed 10/108, failed 91/108, and routed 7/108
to review. All nine intentionally unresolved occurrences remained neutral and passed; the
safe resolver nevertheless missed 84 policy-labelled resolvable occurrences. Required
theology surfaces passed 51/70, and functional-negation checks passed 43/71 applicable
segments. The report is a private, mode-0600 diagnostic artifact with SHA-256
`f43aa47269fa544c15a75aa8f2b8bc5e0341578b42713b0d5fdb134ec5c4bc88`.
Its schema-v2 provenance binds the exact 936-file source snapshot, Release test executable,
model, helper, 13-file runtime bundle, configuration, manifest, and schema. Translation
latency was 1.566 s at p50, 7.618 s at p95, and 13.503 s maximum; 107/144 calls (74.31%)
finished within three seconds. An idle sibling Q8 server remained resident, so those
timings are descriptive and not end-to-end SLA evidence. The hard
and release-ready gates both fail; validator acceptance is not a substitute for blinded
bilingual review.

Later VAD shadow-observation and durable-postflight source changes changed the source-bundle
digest. Consequently this artifact is historical evidence for its pinned snapshot, not the
current working tree. A new exact-tree replay must use a fresh filename and create a
non-overwriting mode-0600 postflight sidecar. That sidecar rehashes the source, executable,
model, helper/runtime bundle, configuration, manifest, and schema and binds the canonical
report bytes; it does not convert a quality-gate failure into a pass.

## Required model and pipeline qualification

Before calling a build production-ready, test the exact Git commit, model revisions,
helper binary, macOS build, and Apple Silicon hardware class. Record:

- Audio input → processing → pinned libfvad hybrid → staged recovery → Qwen3-ASR → audited literal
  normalization → audited discourse resolution → Hy-MT2 → validator → JSONL append →
  recovery completion → local and Safari reader.
- Permission denied/revoked, selected-device unplug/switch, no signal, silence, music,
  short noise, overlap, stream overflow, and maximum segment behavior.
- Missing/corrupt model, interrupted install, disk full, helper startup/exit/timeout,
  rejected translation, transcript finalization failure, crash between each durable step,
  replay, idempotence, and malformed recovery quarantine.
- Long upward reading and **Jump to Live** while entries arrive, glossary save/restore
  failure, selectable complete text, and transcript reopening.
- Viewer/operator invitation expiry, one-time redemption race, revocation, listener
  disable/re-enable, interface changes, slow clients, reconnect/resync, and unauthorized
  Host/Origin/query/frame/request cases on actual iPhone/iPad/Mac Safari devices.
- Eight-hour operation with latency percentiles measured from sentence end, peak and
  steady-state resident memory, thermal state, dropped frames, recovery-directory growth,
  and transcript integrity.
- Memory-pressure termination and relaunch on the minimum supported RAM configuration.

The locked Mandarin corpus must contain at least 12 sermons, 8 hours, and 6 speakers, plus
multiple rooms, microphones, accents, music, and overlap, with consent and no private or
third-party recording committed to Git. Human boundary labels must distinguish natural
completion, incomplete pauses, unsafe clause cuts, and mid-word cuts. The release gates
are zero mid-word cuts, at most 0.2% unsafe early boundaries, endpoint p95 at most 800 ms,
and at least 98% of final English visible within three seconds. Keep the selected libfvad
revision, configuration, notices, and contract tests pinned; AdaptiveEnergy must remain
fallback-only unless it independently meets every gate.

## Translation quality set

The reviewed corpus must cover, at minimum, 救恩, 恩典, 称义, 因信称义, 成圣, 重生,
赎罪, 三位一体, 圣灵, 团契, 事奉, 圣餐, 洗礼, covenant, election, resurrection,
names, Scripture references, negation, numbers, quotations, repetition, code-switching,
pronouns, and long sentences.

Score separately:

- ASR raw character error rate and correction precision/recall.
- Required/preferred terminology accuracy and accepted grammatical variants.
- Translation omissions, additions, altered negation/numbers/references, and hallucination.
- Blinded bilingual human review for fidelity, naturalness, and theological terminology.
- End-of-sentence ASR, translation, persistence, and total reader latency percentiles.
- Pronoun-correction precision, abstention/coverage, evidence age, and forbidden
  gender/deity rewrite count; any wrong automatic gender/deity rewrite fails the gate.
- Non-speech publish rate with and without hotwords across silence, music, singing,
  applause, room noise, and interpreter overlap; any hotword echo or known sentinel
  reaching the transcript fails the gate.

Automated validators are narrow defect detectors, not a substitute for bilingual human
review. A rejected sentence remaining recoverable is safer than publishing an unchecked
guess, but it is still a service interruption to measure.

Negation qualification must not use the current sentence-level cue-presence check as its own
oracle. The deterministic public challenge includes known multi-cue omission and scope false
passes plus non-functional, lexical, and paraphrase false rejects. The public Q4 marker A/B
passed only 4/11 and 3/11 fixtures respectively, with neither encoding passing its two- or
three-occurrence case; both remain test-only. The privacy-safe 24-segment diagnostic likewise
found 0 accepted initial attempts and 0 accepted strict retries. A replacement must first pass
an independent occurrence-count challenge, preserve typed review-required cases, and undergo
blinded scope/event review before it can relax or replace the production fail-closed guard.

A separate public Q4 JSON-Schema shadow verified actual grammar enforcement with a random
nonce absent from the prompt, then compared 13 paired fixtures. Schema output passed its
envelope and required-binding layer on 13/13, but only 1/13 passed the independent application
oracle; negation was 0/4 and pronouns 1/9. The comparison arm was one strict protocol attempt,
not the complete production retry flow. Constrained syntax therefore remains test-only and
cannot substitute for bilingual semantic review.

The offline Policy V2 shadow classified all 144 frozen segments without running a model.
Among 109 outputs accepted by the existing validator, it produced zero narrow structural
passes, routed 45 to review, and classified 64 as having no detected functional negation;
two accepted outputs were routed to review only by its intentionally over-broad Unicode
prototype. Equal cue counts can still attach negation to the wrong event, so Policy V2 is a
diagnostic partition—not an acceptance oracle or production replacement.

## UI, accessibility, and privacy qualification

Native visual QA must compare the built app at the supported window sizes and verify empty,
preparing, listening, translating, failure, long-transcript, scrolled-up, sharing, glossary,
and settings states. Run keyboard-only navigation, VoiceOver, Increase Contrast, Reduce
Motion, text selection, and long-English/Chinese wrapping checks. A rendered screenshot or
unit test alone is not clean-Mac UI evidence.

Verify that normal operation sends no audio, transcript, glossary, or diagnostics off the
Mac. Model installation may contact only manifest-pinned HTTPS artifact hosts. With LAN
sharing off, no listener should exist. With sharing on, confirm that Bonjour and paired
HTTP/WebSocket traffic are local, no third-party asset request occurs, credentials and
transcript content do not enter logs, and disabling sharing revokes grants.

## Release report

A release report must state the Git commit, dependency lock, model revisions and hashes,
arm64 binary/app/DMG hashes and sizes, macOS and Mac model/RAM, automated results, real
corpus identity, human review results, soak duration, latency percentiles, peak memory,
LAN device matrix, Developer ID identity, notarization request ID, stapling validation,
and Gatekeeper launch on a clean standard-user account.

If credentials or clean hardware are unavailable, packaging scripts may produce an
unsigned or ad-hoc engineering artifact. Label it explicitly. Do not call it notarized,
publicly distributed, production-ready, long-sermon validated, or clean-Mac validated.
