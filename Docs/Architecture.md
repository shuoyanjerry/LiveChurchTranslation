# Architecture

## Rules

Dependencies point inward. API targets contain protocols and immutable `Sendable` value
types. Business implementations may import API targets, never concrete adapters. UI may
import UI design primitives and APIs, never inference, audio, or persistence adapters.
Only `ChurchTranslatorApp` knows all concrete types and wires them through initializers.

There are no service locators, mutable globals, cross-feature implementation imports, or
`Shared`, `Common`, and `Utils` targets. Foundation process-wide defaults are permitted
only inside infrastructure adapters or the composition root; business code receives
dependencies explicitly. Every target edge is checked for cycles.

```text
ChurchTranslatorApp (composition root)
  ├── LiveReader + UIDesignSystem
  ├── SessionManagement
  └── concrete infrastructure adapters
               │
               ▼
        small *API contracts
               ▲
               │
      pure business implementations
```

## Module catalog

The following is the central module documentation. Adapter-specific READMEs add native
configuration details where needed.

| Module | Purpose and public API | Allowed dependencies |
| --- | --- | --- |
| `AudioCaptureAPI` | Input IDs/devices, frames, requests, `AudioCaptureProvider` | Foundation |
| `AudioCaptureAVFoundation` | Selected-device microphone capture adapter | `AudioCaptureAPI`, AVFoundation/CoreAudio |
| `AudioProcessingAPI` | Processing configuration, frames, `AudioProcessor` | `AudioCaptureAPI` |
| `AudioProcessingCore` | Validate, downmix, normalize, and stream-resample | audio APIs only |
| `VADAPI` | VAD configuration/events, segments, `VoiceActivityDetector` | `AudioProcessingAPI` |
| `VADCore` | Adaptive-energy sentence segmentation | VAD/audio APIs only |
| `ASRAPI` | `ASRProvider`, immutable request/result, explicit errors | `VADAPI` |
| `ASRQwen3` | sherpa-onnx Qwen3-ASR adapter | `ASRAPI`, pinned sherpa product |
| `ASRNormalizationAPI` | Immutable correction rules and replaceable normalizer protocol | pure Swift |
| `ASRNormalizationCore` | Longest-match, non-cascading Mandarin correction | normalization API only |
| `TranslationAPI` | `TranslationProvider`, requests/results/glossary terms | Foundation |
| `TranslationHyMT2` | Hy-MT2 prompt, local helper lifecycle, output guards | `TranslationAPI`, Foundation |
| `TranslationApple` | Optional replaceable system Translation adapter | `TranslationAPI`, Apple Translation |
| `GlossaryAPI` | Glossary values, service and repository protocols | Foundation |
| `GlossaryCore` | Validation, defaults, ordering, updates | `GlossaryAPI` |
| `GlossaryFileSystem` | Atomic JSON glossary repository | `GlossaryAPI`, Foundation |
| `ModelRuntimeAPI` | Model identity/status and location/reporting protocols | Foundation |
| `ModelRuntimeCore` | Actor-owned locations and observable runtime status | `ModelRuntimeAPI` |
| `ModelDownloadAPI` | Replaceable installation protocol and errors | `ModelRuntimeAPI` |
| `ModelDownloadHTTP` | Manifest-driven HTTPS, hash verification, atomic install | model APIs, Foundation, CryptoKit |
| `TranscriptAPI` | Session/entry/event values and buffer protocol | ASR/translation APIs |
| `TranscriptCore` | Ordered in-memory transcript actor | `TranscriptAPI` |
| `PersistenceAPI` | Replaceable `TranscriptStore` | `TranscriptAPI` |
| `PersistenceFileSystem` | Append-only JSONL/Markdown session storage | persistence/transcript APIs |
| `SettingsAPI` | Settings values and store protocol | pure Swift |
| `SettingsUserDefaults` | Injected UserDefaults adapter | `SettingsAPI`, Foundation |
| `LoggingAPI` | Structured log values and logger protocol | Foundation |
| `LoggingOSLog` | Unified logging adapter | `LoggingAPI`, OSLog |
| `DiagnosticsAPI` | Diagnostic events and recorder protocol | Foundation |
| `DiagnosticsCore` | Bounded actor recorder and export | diagnostics/logging APIs |
| `SessionManagementAPI` | Session states/events and controller protocol | boundary APIs only |
| `SessionManagement` | Explicit live-session state machine and pipeline | boundary APIs only |
| `UIDesignSystem` | Visual tokens and reusable rendering primitives | SwiftUI |
| `LiveReader` | Rendering, view state, and user-intent forwarding | UI system and APIs only |
| `ChurchTranslatorApp` | App entry point and dependency wiring | concrete production targets |

## Ownership and threading

Audio frames, speech segments, recognition results, translation requests, transcript
events, and session snapshots cross modules as values. Actors own capture lifecycle,
model lifecycle, downloads, glossary mutation, transcripts, diagnostics, and session
state. AVFoundation callbacks immediately copy audio into immutable frames. SwiftUI state
is isolated to the main actor. No mutable reference is shared across a module boundary.

## Session state and event flow

```text
idle → preparing → listening ⇄ recognizing → translating → listening → stopping → idle
                         │                         │
                         └──── explicit error ────┴───────────────→ failed
```

Capture emits frames; processing emits normalized mono frames; VAD emits complete speech
segments; ASR emits source utterances; normalization repairs constrained known aliases;
translation emits validated English; session management publishes a reader entry only
after its append-only persistence write succeeds.
Stop flushes pending VAD and queued segments before final session metadata is written.

## Failure boundaries

Permission denial and device changes are capture failures. Invalid audio and silence are
processing/ASR failures. Missing, corrupt, or cancelled artifacts are download failures.
Helper exit, timeout, malformed output, missing glossary terms, numbers, negation, or Bible
reference shapes are translation failures. Filesystem errors never disappear silently.
Session management maps these typed failures to explicit state and diagnostic events.

## Replacement contract

To replace ASR, translation, capture, or storage, implement its API protocol in a new
adapter target, test it with contract fixtures, and change only composition-root wiring.
The architecture gate rejects any attempted dependency from a business or UI target to
that new implementation.

`Scripts/check_architecture.sh` enforces the target graph, cycle freedom, 200-line Swift
file limit, layer imports, composition-root constraints, banned garbage-drawer names,
and singleton rules. A violation exits nonzero locally and in CI.
