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
4. Debug build and all default tests with compiler warnings promoted to errors.
5. Dead-code analysis using the mandatory deterministic scan and Periphery when installed.

GitHub Actions is configured to call the same gate. A local or CI pass is development
evidence only; it is not model-quality, soak, signing, notarization, or clean-Mac evidence.

## Automated suites

| Suite | Evidence provided |
| --- | --- |
| `AudioProcessingCoreTests` | Validation, downmixing, resampling, continuity, and reset |
| `VADCoreTests` | AdaptiveEnergy fallback plus calibrated defaults, raw two-frame endpoint cancellation, soft/preferred/hard boundaries, smoothing, transient rejection, and flush |
| `VADWebRTCTests` | Pinned native libfvad configuration, typed input failures, lifecycle/reset, silence, strong-energy rescue, and independent instances |
| `SemanticEndpointSmartTurnTests` | Input/lifecycle/integrity failures, fixed feature-extraction goldens, and opt-in native-to-Python probability parity |
| `ASRQwen3Tests` | Model layout/configuration, silence/sentinel guards, recursive ordered prompt-prefix stripping, hotword bounds, plus an opt-in real-model WAV smoke harness |
| `ASRNormalizationCoreTests` | Built-ins, editable aliases, longest precedence, non-cascading replacement, and correction audit |
| `DiscourseResolutionCoreTests` | Explicit-evidence `他` / `她` correction and audit plus abstention for competing/stale/unsafe context, quotations, plurals, deity references, names, and occupations |
| `GlossaryCoreTests` | Defaults, aliases/variants, enforcement, validation, and deterministic persistence behavior |
| `TranslationHyMT2Tests` | Prompt isolation, latest-two context cap, ambiguous-pronoun policy, gender faithfulness guards, helper lifecycle, retry/timeout, and structural output guards |
| `TranscriptCoreTests` | Ordered lifecycle, raw/normalized source audit, append events, and compatibility decoding |
| `PersistenceFileSystemTests` | JSONL/Markdown sessions, synchronized append, idempotent IDs, loading, and source audit persistence |
| `UtteranceRecoveryFileSystemTests` | Stage/restart/complete lifecycle, cross-session ordering, bounds, tombstones, and quarantine |
| `ModelDownloadHTTPTests` | Manifest validation, hashing, exact sizes, atomic install, cancellation, and deduplication |
| `SessionManagementTests` | Fake-provider end-to-end pipeline, state/stop ordering, stage-before-inference, discourse-before-translation, persisted-only two-turn context, audit, replay, and persistence failures |
| `LiveReaderTests` | Follow intent, unseen counts, transcript formatting, and sharing presentation contracts |
| `RemotePairingCoreTests` | Entropy shape, expiry, races, role enforcement, hashing, revocation, and audit redaction |
| `RemoteControlCoreTests` | Viewer denial, operator Start/Stop, stale revisions, concurrent races, replay, and target failure |
| `RemoteControlSessionAdapterTests` | Mac-selected input preservation and Start/Stop mapping |
| `RemoteProjectionCoreTests` | Snapshot/live barrier, revisions, late entries, bounds, slow-peer resync, and default-off switch |
| `RemoteProjectionSessionAdapterTests` | Session/entry mapping, resets, delta publication, and error redaction |
| `RemoteSharingFeatureTests` | Enable/disable, invitations, presentation state, peers, and revocation with protocol fakes |
| `RemoteDiscoveryBonjourTests` | Fixed service type and credential-free, bounded metadata |
| `RemoteWebAssetsTests` | Asset allowlist, no third-party URLs, and Safari reader security assumptions |
| `RemoteTransportNetworkTests` | Bounded HTTP/WebSocket parsing, Host/Origin policy, cookie parity, headers, viewer denial, and a real localhost listener/snapshot/delta smoke test |

Most tests use protocol fakes and temporary directories. The default gate does not
download model weights, use a real microphone, or launch Safari. The network suite does
open an ephemeral loopback `NWListener`; it is not a multi-device or hostile-network test.

## Opt-in real-model smoke tests

Model tests run only when explicit local inputs are provided:

```sh
QWEN_MODEL_DIR=/path/to/qwen QWEN_TEST_WAV=/path/to/16k-mono.wav \
  swift test --filter Qwen3RealModelSmokeTests

HYMT_MODEL_DIR=/path/to/hy-mt2 HYMT_LLAMA_SERVER=/path/to/llama-server \
  swift test --filter HyMT2RealModelSmokeTests

SMART_TURN_REAL_MODEL_TESTS=1 \
SMART_TURN_MODEL_PATH=/path/to/smart-turn-v3.2-cpu.onnx \
SMART_TURN_TEST_WAV=/path/to/16k-mono.wav \
  swift test --filter SmartTurnRealModelParityTests
```

The Qwen test reports raw output, normalized output, the correction audit, audio duration,
and decode duration. The Hy-MT2 test reports outputs and sentence inference durations.
These are smoke harnesses, not quality claims. Do not use measurements from the sibling
`church_translation` project, including its long-sermon run, as validation of this exact
Qwen3-ASR/Hy-MT2 app stack.

The 2026-08-21 final reruns recorded one 5.93-second Qwen fixture at 1.283 seconds decode
and four Hy-MT2 theological fixtures at 0.461–0.864 seconds; the five-case suite including
one discourse-pronoun case completed in 4.483 seconds. Qwen corrected
`因信生义` → `因信称义`; `在圣灵里承受` remained unchanged and therefore did not qualify
成圣 recognition. An earlier run also exercised `休恩` → `救恩`. See
[the engineering snapshot](ReleaseQualification-2026-08-21.md).

The Smart Turn parity fixture is pinned to the upstream model probability. Passing it
demonstrates adapter parity for one waveform, not a safe Mandarin decision threshold.

## Observed Mandarin-sermon replay

The 2026-08-21 offline replay used four public church recordings totaling 4 h 1 m 54 s for
endpoint behavior and six clips totaling exactly 50 minutes for the exact Qwen3-ASR INT8
stack. The selected Swift libfvad/WebRTC hybrid produced 1,063 segments with 29 under two
seconds, 366 hard-cap closures, and 288 preferred-boundary closures. It matched the pinned
sibling WebRTC classifier on all 725,722 frames. The replay also found serious
non-speech/hotword failure cases. Five reviewed discourse cases from three Mandarin
spiritual messages passed; a sixth object-pronoun case remains an intentional abstention
and known coverage gap. Exact numbers, source provenance, Smart Turn shadow distributions,
rights policy, and limitations are recorded in
[the Mandarin discourse and endpoint report](MandarinDiscourseAndEndpointQualification-2026-08-21.md).

This was offline component replay. It did not exercise microphone capture, durable
recovery, translation, and reader latency continuously over four hours, and it had no
time-aligned verbatim gold transcript. Do not label it a WER/CER result, semantic-boundary
accuracy result, 1–3 second SLA, or long-running end-to-end qualification.

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
