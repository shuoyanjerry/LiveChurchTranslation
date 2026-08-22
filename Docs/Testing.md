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
| `VADCoreTests` | Smoothing, pre/post roll, normal and soft silence, maximum duration, transient rejection, and flush |
| `ASRQwen3Tests` | Model layout/configuration plus an opt-in real-model WAV smoke harness |
| `ASRNormalizationCoreTests` | Built-ins, editable aliases, longest precedence, non-cascading replacement, and correction audit |
| `GlossaryCoreTests` | Defaults, aliases/variants, enforcement, validation, and deterministic persistence behavior |
| `TranslationHyMT2Tests` | Prompt isolation, latest-two context cap, helper lifecycle, retry/timeout, and structural output guards |
| `TranscriptCoreTests` | Ordered lifecycle, raw/normalized source audit, append events, and compatibility decoding |
| `PersistenceFileSystemTests` | JSONL/Markdown sessions, synchronized append, idempotent IDs, loading, and source audit persistence |
| `UtteranceRecoveryFileSystemTests` | Stage/restart/complete lifecycle, cross-session ordering, bounds, tombstones, and quarantine |
| `ModelDownloadHTTPTests` | Manifest validation, hashing, exact sizes, atomic install, cancellation, and deduplication |
| `SessionManagementTests` | Fake-provider end-to-end pipeline, state/stop ordering, stage-before-inference, replay, persistence failures, and two-entry context |
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
```

The Qwen test reports raw output, normalized output, the correction audit, audio duration,
and decode duration. The Hy-MT2 test reports outputs and sentence inference durations.
These are smoke harnesses, not quality claims. Do not use measurements from the sibling
`church_translation` project, including its long-sermon run, as validation of this exact
Qwen3-ASR/Hy-MT2 app stack.

The final 2026-08-21 rerun recorded one 5.93-second Qwen fixture at 1.757 seconds decode
and four Hy-MT2 fixtures at 0.596–1.206 seconds. Qwen corrected
`因信生义` → `因信称义`; `在圣灵里承受` remained unchanged and therefore did not qualify
成圣 recognition. An earlier run also exercised `休恩` → `救恩`. See
[the engineering snapshot](ReleaseQualification-2026-08-21.md).

## Required model and pipeline qualification

Before calling a build production-ready, test the exact Git commit, model revisions,
helper binary, macOS build, and Apple Silicon hardware class. Record:

- Audio input → processing → VAD → staged recovery → Qwen3-ASR → audited correction →
  Hy-MT2 → validator → JSONL append → recovery completion → local and Safari reader.
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

The Mandarin corpus must include multiple speakers, rooms, microphones, accents, music,
and overlap, with consent and no private recordings committed to Git.

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
