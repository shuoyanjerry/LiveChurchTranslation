# Quiet Liturgy Reader

Quiet Liturgy Reader is a focused macOS tool for one workflow only: capture Chinese
speech, recognize Mandarin locally, translate it faithfully into English, and keep the
complete result readable during a church service. It is not a presentation system,
sermon summarizer, or OBS companion.

The app targets arm64 Apple Silicon and does not require users to install Python, Node,
Ollama, LocalVocal, llama.cpp, or another runtime.

## What it does

- Captures a selected microphone or audio input and forms sentence-sized segments with
  voice activity detection.
- Runs Qwen3-ASR 0.6B INT8 locally through the pinned sherpa-onnx Swift package.
- Applies only literal, reviewed Mandarin alias corrections. Every transcript entry
  retains the raw ASR text, normalized text, and the exact correction audit.
- Translates with Tencent Hy-MT2 1.8B Q4_K_M through an app-bundled llama.cpp helper.
  The prompt requires clause-by-clause translation without summaries, additions, or
  omissions. Validators check required glossary terms, numbers, negation, Scripture
  reference shape, implausible length, and model commentary.
- Supports an editable theological glossary with source aliases, ASR aliases, accepted
  English variants, and `required` or `preferred` enforcement.
- Gives Hy-MT2 only the latest two validator-approved and durably appended Chinese/English
  pairs as background. The current sentence is delimited separately, and context is never
  treated as text to output.
- Shows a continuous English reader with optional Chinese, selectable text, timestamps,
  stable upward reading, an unseen-entry count, and **Jump to Live**.
- Writes each accepted entry to local JSONL and produces a Markdown transcript for the
  session.

Validation catches specific structural defects; it cannot prove that a translation is
theologically or linguistically correct. Human review remains a release requirement.

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
a paired Safari device can receive the live reader. A viewer is read-only; an operator can
request only **Start** or **Stop**, using the input already selected on the Mac. Remote APIs
cannot change the microphone, glossary, model, settings, history, export, or app lifecycle.
The Mac remains the sole inference host and transcript writer.

Pairing uses single-use, expiring invitations, high-entropy credentials, role checks,
revocation, bounded connections, strict Host/Origin policy, and hardened no-cache web
responses. The current LAN transport is HTTP/WebSocket without TLS. Pairing provides
authorization, not confidentiality against a hostile network observer; enable sharing
only on a trusted local network and disable or revoke it after the service.

See [Architecture](Docs/Architecture.md) for the complete trust boundary and dependency
graph.

## Platform and model installation

- Minimum deployment target: macOS 15, arm64 Apple Silicon.
- ASR: Qwen3-ASR 0.6B INT8, revision-pinned model artifacts.
- Translation: Hy-MT2 1.8B Q4_K_M GGUF, revision-pinned artifact.
- Runtime dependency: sherpa-onnx 1.13.6 is exact-version pinned; the translation helper
  is bundled with the release app.

Models are not stored in Git. First use downloads about 2.12 GB over HTTPS, verifies each
artifact's exact byte count and SHA-256, and installs it atomically. Once installed, ASR
and translation run locally. LAN sharing creates network traffic only when explicitly
enabled.

## Repository architecture

The Swift package is divided into small API, domain, infrastructure, feature, and
composition targets. Cross-module values are immutable and `Sendable`; mutable lifecycle
state is actor-owned. Business orchestration depends on protocols, not SwiftUI, storage,
Apple audio frameworks, model SDKs, or network implementations. `ChurchTranslatorApp` is
the only composition root.

- [Architecture and module catalog](Docs/Architecture.md)
- [Tests and release qualification](Docs/Testing.md)
- Per-target `README.md` files document purpose, public API, dependencies, threading,
  failures, and tests.

## Build and verify

Development requires Swift 6.1 and Xcode 16.4, or a compatible newer toolchain.

```sh
./Scripts/check.sh
```

The gate checks architecture and cycles, the 200-line Swift file limit, formatting,
SwiftLint, warnings-as-errors builds and tests, and dead code. See
[Testing](Docs/Testing.md) before interpreting a green local gate as release evidence.

## Use

1. Launch Quiet Liturgy Reader and allow microphone access.
2. Select the desired input and review the glossary if needed.
3. Choose **Start**. First use installs and verifies the local models.
4. Read the continuous English transcript. Scroll upward freely; choose **Jump to Live**
   when ready to resume following.
5. Choose **Stop** to flush queued speech and finalize the transcript.
6. Optionally open **Share**, enable local sharing, and create a viewer or operator
   invitation for a trusted Safari device.

Application data is stored under
`~/Library/Application Support/LiveChurchTranslation/`, including `Models`, `Glossary`,
`Transcripts`, `Diagnostics`, and the hidden pending-utterance recovery directory.

## Distribution status and licensing

Build scripts can create engineering `.app` and `.dmg` artifacts. A build is not a
public release unless its release report records Developer ID signing, notarization,
stapling, Gatekeeper launch on a clean Mac, exact model revisions, hashes, hardware tests,
and quality review. This repository does not claim those results in this README.

The source is MIT licensed. Model weights and bundled third-party code retain their own
licenses; review `THIRD_PARTY_NOTICES.md` before distribution. The visual system is an
original, restrained church-reader design inspired by the Northville context. It does
not include or redistribute The Church in Northville's official logo, photography, or
other brand assets, and this project does not claim affiliation or endorsement.
