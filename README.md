# Live Church Translation

Live Church Translation is a privacy-first macOS application for sentence-level,
real-time Mandarin sermon transcription and faithful English translation. Inference
runs locally on Apple Silicon. The installed app does not require Python, Node,
Ollama, OBS, LocalVocal, or another user-managed runtime.

## Product behavior

- Select an audio input, grant microphone access, and start a session.
- Voice activity detection closes sentence-sized speech segments before recognition.
- Qwen3-ASR recognizes Mandarin; constrained ASR aliases repair known mishearings;
  Hy-MT2 translates with an editable theological glossary and output-integrity checks.
- The live reader keeps the complete session visible. Reading older text disables
  automatic following until **Jump to Live** is selected.
- Every accepted entry is appended to a recoverable local transcript.

The application never summarizes a sermon. Validation rejects suspicious translation
output; it cannot prove theological correctness. Release qualification therefore uses
human-reviewed church and Bible fixtures in addition to automated tests.

## Platform and models

- Deployment target: macOS 15 or newer, arm64 Apple Silicon.
- ASR adapter: Qwen3-ASR 0.6B INT8 through the pinned sherpa-onnx Swift package.
- Translation adapter: Tencent Hy-MT2 1.8B Q4_K_M through a bundled, pinned
  llama.cpp helper that is restricted to an authenticated IPv4 loopback endpoint.
- Models are not stored in Git. First use downloads revision-pinned artifacts over
  HTTPS, verifies exact size and SHA-256, and installs them atomically.

Model files consume roughly 2.2 GB before filesystem overhead. The release app size,
latency, memory ceiling, signing identity, and notarization ticket are release outputs,
not constants; do not infer them from this README.

## Architecture

The repository is intentionally split into small Swift Package targets. Domain
protocols and immutable values live in `*API` targets. Business orchestration depends
only on those protocols. Apple frameworks, model SDKs, the filesystem, and process
management remain behind adapter targets. `ChurchTranslatorApp` is only the composition
root; `LiveReader` only renders state and forwards user intent.

See [Architecture](Docs/Architecture.md) for module contracts and the dependency rules.
See [Testing](Docs/Testing.md) for automated gates and release-qualification evidence.

## Developer verification

Full development requires Swift 6.1 and Xcode 16.4 or a compatible newer toolchain.

```sh
./Scripts/check.sh
```

That command enforces architecture and file-size constraints, formatting, warnings as
errors, tests, and dead-code checks. SwiftLint 0.65.0 is mandatory and fetched from its
checksum-pinned official artifact when needed. Periphery augments the mandatory static
dead-code check when it is installed.

## Install and use

Open the DMG, drag **Live Church Translation** to Applications, then launch it. Select an
input device, edit the theological glossary or ASR aliases if desired, and choose
**Start**. The first session downloads and verifies about 2.12 GB of model files. Later
sessions run recognition and translation offline. Use **Jump to Live** after reading
older text; transcripts are stored under `~/Library/Application Support/LiveChurchTranslation/Transcripts`.

## Privacy, licensing, and distribution

Audio, recognized text, translations, glossary data, and transcripts stay on the Mac.
Only explicit model installation performs network requests. A distributable build must
include model and third-party notices, a hardened-runtime signature, microphone usage
text, and notarization/stapling evidence. Developer ID credentials are intentionally
not committed.

The application source is MIT licensed. Model weights and bundled third-party code keep
their own upstream licenses; review `THIRD_PARTY_NOTICES.md` in a release before shipping.
