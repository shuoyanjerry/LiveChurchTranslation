# Live Church Translation

[简体中文](README.zh-CN.md) | English

Live Church Translation is a focused macOS tool for live church translation and listening
notes. It supports Mandarin-to-English and English-to-Simplified-Chinese modes, preserves
the complete meeting recording and transcript, and serves the live reader to paired
phones, tablets, and computers on the local network.

The app targets arm64 Apple Silicon and does not require users to install Python, Node,
Ollama, LocalVocal, llama.cpp, or another runtime.

## What it does

- Captures a selected microphone or audio input and forms sentence-sized segments with
  voice activity detection.
- Lets the operator choose Mandarin-to-English or English-to-Simplified-Chinese before a
  session. The choice is stored with the transcript and projected to remote readers.
- Saves complete live-session audio as crash-recoverable CAF together with its transcript,
  and provides a searchable local library with playback and deletion controls.
- Imports system-readable audio files, including WAV, AIFF, MP3, AAC/M4A, and CAF, for
  bounded-memory transcription in either language direction.
- Runs Qwen3-ASR 0.6B INT8 locally through the pinned sherpa-onnx Swift package.
- Applies only literal, reviewed Mandarin alias corrections. Every transcript entry
  retains the raw ASR text, normalized text, and the exact correction audit.
- Translates with Tencent Hy-MT2 1.8B Q4_K_M through an app-bundled llama.cpp helper.
  The prompt requires clause-by-clause translation without summaries, additions, or
  omissions. Validators check required glossary terms, numbers, negation, Scripture
  reference shape, implausible length, and model commentary.
- Supports an editable theological glossary with source aliases, ASR aliases, accepted
  English variants, and `required` or `preferred` enforcement.
- Gives Hy-MT2 only the latest two validator-approved and durably appended source/target
  pairs as background. The current sentence is delimited separately, and context is never
  treated as text to output.
- Shows a continuous target-language reader with optional recognized source text, stable
  upward reading, an unseen-entry count, and **Jump to Live**.
- Writes each accepted entry to local JSONL and produces a readable Markdown transcript
  for the session.

Validation catches specific structural defects; it cannot prove that a translation is
theologically or linguistically correct. Human review remains a release requirement.

The test target also contains a public-only, test-only negation occurrence-marker shadow.
It compares two Q4 prompt encodings (an English `not` placeholder and the original Chinese
cue), numbers only human-annotated functional negations as `N0001` and later, and accepts a
trial only when every nonce-bound block appears exactly once beside an overt allowlisted
English negator. The parser removes every accepted block and rejects protocol residue.
Lexical, additive, concessive, and A-not-A constructions are deliberately left unmarked.
Shadow assessment records only encoding, occurrence count, and a bounded pass/failure code,
plus a SHA-256 of each raw UTF-8 model output; it never records source text, prompt text,
model output text, or cleaned translation. This experiment does not change the production
prompt, API, or validator, and a structural shadow pass does not prove semantic scope or
translation fidelity.

The pinned public Q4 A/B qualification uses seed 42, temperature 0, and four threads. Its
current strict result is 4/11 for the English-placeholder encoding and 3/11 for the
original-cue encoding; neither encoding preserved a passing two- or three-occurrence case.
Both remain rejected for production. An unrelated idle Q8 server was resident during the
run, so the content and structure findings are usable but the recorded latencies are
explicitly uncontrolled and are not performance-release evidence.

## Quiet progress and timing feedback

The interaction contract keeps long-running work visible without interrupting the reader.
The Mac and paired browser use a small, persistent status treatment for **Preparing**,
**Listening**, **Recognizing**, **Translating**, and **Finishing**, followed by native
**Incomplete** or browser **Paused** when work cannot continue. Recording time is shown separately
so that it cannot hide the current processing phase. **Connecting**,
**Connected**, and **Reconnecting** remain distinct sharing states. Transient phases may use a
restrained activity indicator; ordinary progress is never announced as a surprise alert or inserted
as transcript text.

Passage timestamps are visible by default and may be hidden independently on the Mac and in the
browser. Hiding timestamps changes presentation only: recorded offsets remain in JSONL, Markdown,
and the session library.

On 2026-08-24, the correction tree passed the complete command-line quality gate. Full-Xcode
Archive/signing checks and repeated real-device Safari verification are still required before these
interaction changes or the LAN crash correction become release evidence.

## Crash-safe sentence handoff

Every completed VAD segment is staged durably before ASR begins. Its recovery record is
removed only after the translated entry has been appended to the transcript. On a later
start, pending records are replayed in session and sequence order. Corrupt, partial,
or oversized artifacts are quarantined and surfaced as recoverable issues instead of
being silently discarded.

The recovery directory contains temporary sermon audio. It stays under the app's local
Application Support directory and is deleted after successful handoff; quarantine is
retained for diagnosis until the user removes the app data.

## Optional local-network reader

Local sharing is off by default. When the Mac user enables it and creates an invitation,
a paired Safari device can receive the live reader. Invitations issued by this release are
viewer-only. Remote APIs cannot start or stop capture, accept the recording notice, or change
the microphone, glossary, model, settings, history, export, or app lifecycle. The Mac remains
the sole inference host, recording-consent surface, and transcript writer.

The viewer link uses a high-entropy, reusable session credential held only in memory. It remains
valid while the app and sharing session stay open, including across transient listener retries, and
is rotated only when sharing is explicitly stopped or the app exits. Browser grants use session
cookies. Pairing also enforces role checks, revocation, bounded connections, strict Host/Origin
policy, and hardened no-cache responses. The current LAN transport is HTTP/WebSocket without TLS.
Pairing provides authorization, not confidentiality against a hostile network observer; enable
sharing only on a trusted local network and stop or revoke it after the service.

Two macOS 15.5 crash reports from 2026-08-24 showed the distributed engineering build trapping in
`WebSocketFrameCodec.parseClientFrame(_:)` after Safari connected. They invalidate the earlier
loopback-only sharing conclusion. The correction removes a zero-origin `Data` indexing assumption;
release acceptance now requires receive-split and coalesced-frame regressions plus repeated real Safari
pairing, heartbeat, reconnect, and stop/restart checks without a process crash. See
[Testing](Docs/Testing.md) for the pending gate.

See [Architecture](Docs/Architecture.md) for the complete trust boundary and dependency graph.

## Platform and model installation

- Minimum deployment target: macOS 15, arm64 Apple Silicon.
- ASR: Qwen3-ASR 0.6B INT8, revision-pinned model artifacts.
- Translation: Hy-MT2 1.8B Q4_K_M GGUF, revision-pinned artifact.
- Speech segmentation: native libfvad/WebRTC mode 2 at pinned commit `532ab666`,
  wrapped behind `VADAPI` with calibrated sermon timing and an AdaptiveEnergy fallback.
- Runtime dependency: sherpa-onnx 1.13.6 is exact-version pinned; the translation helper
  is bundled with the release app.

Models are not stored in Git. A release build fetches the seven artifacts from immutable
revisions, verifies their exact byte counts and SHA-256 values, and seals all 2,120,095,795
bytes inside `Contents/Resources/Models` before signing. The signed app verifies and loads that
inventory locally, so a fresh installation does not need a first-run model download. Debug
source builds may retain the verified HTTPS installer as a development fallback. A candidate
is not releasable until it passes the clean-Mac, network-disabled launch test; packaging alone
is not that evidence. LAN sharing creates network traffic only when explicitly enabled.

The same generic arm64 build path covers M-series Macs that can run macOS 15. Current real-model
performance evidence is from an M1 Pro with 16 GB; the base M1 with 8 GB remains the minimum-hardware
performance gate documented in the English ASR selection report.

## Repository architecture

The Swift package is divided into small API, domain, infrastructure, feature, and
composition targets. Cross-module values are immutable and `Sendable`; mutable lifecycle
state is actor-owned. Business orchestration depends on protocols, not SwiftUI, storage,
Apple audio frameworks, model SDKs, or network implementations. `ChurchTranslatorApp` is
the only composition root.

- [Architecture and module catalog](Docs/Architecture.md)
- [Tests and release qualification](Docs/Testing.md)
- [Production takeover and current gates](Docs/ProductionTakeover-2026-08-24.md)
- [English ASR production selection](Docs/EnglishASRSelection-2026-08-23.md)
- [English-to-Simplified-Chinese theological qualification](Docs/EnglishTranslationQualification-2026-08-22.md)
- [Scripture terminology and rights gate](Docs/ScriptureStandards.md)
- [Mac App Store submission runbook](Docs/AppStoreSubmission.md)
- Per-target `README.md` files document purpose, public API, dependencies, threading,
  failures, and tests.

## Build and verify

Development requires Swift 6.1 and Xcode 16.4, or a compatible newer toolchain.

```sh
./Scripts/check.sh
```

The gate checks architecture and cycles, the 200-line project-owned source-file limit,
formatting, SwiftLint, warnings-as-errors builds and tests, and dead code. Full Xcode remains
required for the tracked application project, Archive, signing, and macOS UI/device verification.
See [Testing](Docs/Testing.md) before interpreting a green local gate as release evidence.

## Use

1. Launch Live Church Translation. Bundled-model verification and loading begin
   automatically. If microphone access is not already authorized, follow the in-app explanation;
   returning from System Settings refreshes permission state automatically.
2. Select the language direction, desired input, and glossary if needed.
3. Choose **Start** and confirm that participants know the meeting is being recorded. Secure
   local recording begins before model loading finishes, so early audio is retained.
4. Follow the quiet processing status and read the continuous translation. Scroll upward freely;
   choose **Jump to Live** when ready to resume following. Show or hide passage timestamps as needed.
5. Choose **Stop** to flush queued speech and atomically finalize the recording and
   transcript in **Library**.
6. Optionally open **Share**, enable local sharing, and create a viewer invitation for a
   trusted Safari device. The current LAN transport is not encrypted.
7. To transcribe an existing recording, open **Library**, choose **+**, select an audio
   file, and keep the app open until import finishes.

Application data is stored under
`~/Library/Application Support/LiveChurchTranslation/`, including development model caches,
`Glossary`, `Transcripts`, `Diagnostics`, and the hidden pending-utterance recovery directory.

## Distribution status and licensing

The delivery target is an internal church application engineered to Mac App Store quality
standards; an actual App Store submission is not required. Build scripts can create engineering
`.app` and `.dmg` artifacts. Any distributed build still needs its exact model revisions, hashes,
hardware tests, and quality review recorded. The current LAN correction and interaction changes
passed the complete command-line gate on 2026-08-24. They have not yet completed their full-Xcode
or real-device acceptance gates.

The pinned [GitHub Release workflow](Docs/GitHubRelease.md) defaults to a non-publishing dry run.
A `vMAJOR.MINOR.PATCH` tag requires Developer ID signing and Apple notarization, then creates only
a draft prerelease candidate with checksums and provenance. Public promotion remains a separate
human decision after every gate in [Testing](Docs/Testing.md) has current evidence.

The source is MIT licensed. Model weights and bundled third-party code retain their own
licenses; review `THIRD_PARTY_NOTICES.md` before distribution. The visual system is an
original, restrained church-reader design inspired by the Northville context. It does
not include or redistribute The Church in Northville's official logo, photography, or
other brand assets, and this project does not claim affiliation or endorsement.

## Developer

The sole developer and maintainer is
[shuoyanjerry](https://github.com/shuoyanjerry) (`jerryyanshuo@outlook.com`). Third-party
authorship shown in bundled license notices applies only to those upstream components.
