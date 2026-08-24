# Live Reader

## Purpose

Renders user intent and immutable presentation state for the focused workflow: audio input and language
direction selection, recognition and translation progress, continuous reading, transcript controls,
glossary, settings, and optional local sharing.

The feature contains no audio processing, inference, translation, persistence, or network implementation.

## Public API

- `LiveReaderView`: the SwiftUI feature entry point.
- `LiveReaderViewModel`: main-actor adapter over explicit application protocols.
- `LiveFollowState`: testable user-scroll intent state.
Local sharing state and intent are injected from `RemoteSharingFeatureAPI`; this target does not define or
implement networking contracts.
Audio-file import intent is injected through `AudioImportAPI`; decoding and session orchestration remain
outside the presentation target.

The initial reader task starts model preparation automatically, observes the
combined ASR and translation progress, and exposes a retry only after bounded
automatic retries are exhausted.

The header maps session work to quiet, persistent `准备中`, `正在聆听`, `正在识别`, `正在翻译`,
`正在完成`, and `未完成` presentation states. The red recording dot and elapsed duration are separate
from that phase. Passage timestamps are visible by default and may be hidden with the persisted
`AppSettings.showTimestamps` preference; hiding them never changes transcript timing.

## Dependencies

The target imports only API boundaries for audio capture, audio import, glossary, model runtime, session
management, settings, and transcript data, plus `UIDesignSystem`. It does not import concrete model,
storage, audio, or LAN implementations.

## Threading Model

`LiveReaderViewModel` is `@MainActor`. It consumes session events asynchronously and publishes immutable snapshots. SwiftUI emits local-sharing intent through a main-actor handler. Mutable reader-follow state is owned by the view.

## Failure Modes

The interface reduces failures to short actionable messages while protocol and storage layers own technical
diagnostics. A settings sheet remains open when persistence fails. Sharing failures arrive as presentation
state; the UI cannot bypass pairing or authorization. Transcript entries remain selectable and are never
deleted by this module.
The library describes complete recordings in user terms and does not expose internal storage filenames.
Language mode and microphone controls are disabled while a session is active, and the recording indicator
appears only after the capture provider has actually started.

## Tests

`LiveReaderTests` verifies live-follow intent, unseen counts, phase/status presentation, timestamp
preference compatibility and persistence, transcript formatting, QR-code round trips, and the immutable
sharing presentation contract. Native visual, accessibility, and clean-Mac UI qualification are tracked
separately in `Docs/Testing.md`.
