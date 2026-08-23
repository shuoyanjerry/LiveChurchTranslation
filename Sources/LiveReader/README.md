# Live Reader

## Purpose

Renders user intent and immutable presentation state for the focused workflow: audio input selection,
Chinese recognition status, English translation, continuous reading, transcript controls, glossary,
settings, and optional local sharing.

When transcript audit metadata marks one or more spoken Mandarin pronouns as unresolved,
`TranscriptPassage` shows a quiet, non-blocking note that neutral English was used. The note never
guesses gender, changes transcript content, or introduces an editing path.

The feature contains no audio processing, inference, translation, persistence, or network implementation.

## Public API

- `LiveReaderView`: the SwiftUI feature entry point.
- `LiveReaderViewModel`: main-actor adapter over explicit application protocols.
- `LiveFollowState`: testable user-scroll intent state.
Local sharing state and intent are injected from `RemoteSharingFeatureAPI`; this target does not define or
implement networking contracts.

The initial reader task starts model preparation automatically, observes the
combined ASR and translation progress, and exposes a retry only after bounded
automatic retries are exhausted.

## Dependencies

The target imports only API boundaries for audio capture, glossary, model runtime, session management, settings, and transcript data, plus `UIDesignSystem`. It does not import concrete model, storage, audio, or LAN implementations.

## Threading Model

`LiveReaderViewModel` is `@MainActor`. It consumes session events asynchronously and publishes immutable snapshots. SwiftUI emits local-sharing intent through a main-actor handler. Mutable reader-follow state is owned by the view.

## Failure Modes

Protocol failures are converted to a visible alert. A settings sheet remains open when persistence fails. Sharing failures arrive as presentation state; the UI cannot bypass pairing or authorization. Transcript entries remain selectable and are never deleted by this module.
Language mode and microphone controls are disabled while a session is active, and the recording indicator
appears only after the capture provider has actually started.

## Tests

`LiveReaderTests` verifies live-follow intent, unseen counts, timestamp/transcript formatting, unresolved
pronoun notice copy, and the immutable sharing presentation contract. Native visual, accessibility, and
clean-Mac UI qualification are tracked separately in `Docs/Testing.md`.
