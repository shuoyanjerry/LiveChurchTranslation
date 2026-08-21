# Testing and Release Qualification

## One-command gate

Run from the repository root:

```sh
./Scripts/check.sh
```

The command stops at the first failed phase:

1. Architecture, dependency-cycle, layer, singleton, and 200-line checks.
2. `swift format lint --strict` using the committed configuration.
3. SwiftLint 0.65.0 in strict mode. If it is not installed, the gate downloads the
   revision-pinned official artifact, verifies SHA-256, and caches it under `.artifacts`.
4. Debug build and tests with compiler warnings promoted to errors.
5. Dead-code analysis: Periphery when installed, plus a mandatory deterministic scan for
   unreferenced private declarations.

GitHub Actions invokes this same script instead of maintaining a divergent CI sequence.

## Automated suites

| Suite | Scope |
| --- | --- |
| `AudioProcessingCoreTests` | Validation, channel mixing, resampling, continuity, reset |
| `VADCoreTests` | Silence, speech lifecycle, boundaries, flush, configuration failures |
| `GlossaryCoreTests` | Defaults, validation, deterministic replacement |
| `ASRNormalizationCoreTests` | Built-ins, editable aliases, precedence, non-cascading replacement |
| `TranscriptCoreTests` | Ordered append, session lifecycle, event publication |
| `PersistenceFileSystemTests` | Session creation, append-only output, recovery metadata |
| `ModelDownloadHTTPTests` | Manifest rejection, hashing, atomic install, cancellation, deduplication |
| `TranslationHyMT2Tests` | Prompt rules, lifecycle, retry limit, timeout, output integrity guards |
| `SessionManagementTests` | Fake-provider pipeline and state-machine integration |

Tests use protocol fakes and temporary directories. The default gate does not download
weights, open a microphone, start the real model helper, or require network access. Two
real-model qualification tests remain disabled unless their explicit inputs are supplied:

```sh
QWEN_MODEL_DIR=/path/to/qwen QWEN_TEST_WAV=/path/to/16k-mono.wav \
  swift test --filter Qwen3RealModelSmokeTests

HYMT_MODEL_DIR=/path/to/hy-mt2 HYMT_LLAMA_SERVER=/path/to/llama-server \
  swift test --filter HyMT2RealModelSmokeTests
```

These tests print raw/normalized recognition, translated text, and measured inference
durations. Model-loading time is reported separately from sentence-end inference.

## Required integration evidence

Before labeling a build production-ready, record results for this exact app, model
revision, and hardware class:

- Audio input → processing → VAD → ASR → normalization → translation → transcript → reader event flow.
- Permission denied, revoked permission, input unplug/switch, and stream overflow.
- Silence, short noise, maximum segment, model load failure, helper exit, corrupt output,
  download cancellation, disk-full, and restart recovery.
- Reader follow behavior while the user is scrolled up, **Jump to Live**, glossary edits,
  and automatic transcript recovery.
- Eight-hour soak with resident memory, thermal state, dropped frames, and latency percentiles.
- Memory-pressure termination/relaunch on the minimum supported RAM configuration.
- Mandarin church recordings from multiple speakers, rooms, microphones, accents, music,
  and overlapping speech, with documented consent and no committed private audio.

Automated green tests are necessary but do not substitute for this hardware evidence.

## Translation quality set

The reviewed corpus must cover salvation, grace, justification, justification by faith,
sanctification, regeneration, atonement, Trinity, Holy Spirit, fellowship, ministry,
Lord's Supper, baptism, covenant, election, resurrection, and Scripture references.
Include negation, numbers, quotations, repeated phrases, code-switching, and long sentences.

Score ASR and translation separately. Record character/word error rate, required-term
accuracy, omission/addition/negation defects, reference preservation, and blinded human
review. Validators reduce obvious failures; they are not a theological-quality metric.

## Release checks

A release report must state the Git commit, dependency lock, model revisions and hashes,
arm64 binary/app/DMG hashes and sizes, macOS version, Mac model/RAM, tests, soak duration,
latency percentiles, peak memory, Developer ID identity, notarization request ID, stapling
validation, and Gatekeeper launch result on a clean standard user account.

If signing credentials or clean hardware are unavailable, package scripts may produce an
unsigned or ad-hoc engineering artifact, but it must be labeled that way and must not be
reported as notarized or clean-Mac validated.
