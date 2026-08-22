# Live Reader

## Purpose

Renders user intent and immutable presentation state for the focused workflow: audio input selection, Chinese recognition status, English translation, continuous reading, transcript controls, glossary, settings, and optional local sharing.

The feature contains no audio processing, inference, translation, persistence, or network implementation.

## Public API

- `LiveReaderView`: the SwiftUI feature entry point.
- `LiveReaderViewModel`: main-actor adapter over explicit application protocols.
- `LiveFollowState`: testable user-scroll intent state.
Local sharing state and intent are injected from `RemoteSharingFeatureAPI`; this target does not define or
implement networking contracts.

## Dependencies

The target imports only API boundaries for audio capture, glossary, model runtime, session management, settings, and transcript data, plus `UIDesignSystem`. It does not import concrete model, storage, audio, or LAN implementations.

## Threading Model

`LiveReaderViewModel` is `@MainActor`. It consumes session events asynchronously and publishes immutable snapshots. SwiftUI emits local-sharing intent through a main-actor handler. Mutable reader-follow state is owned by the view.

## Failure Modes

Protocol failures are converted to a visible alert. A settings sheet remains open when persistence fails. Sharing failures arrive as presentation state; the UI cannot bypass pairing or authorization. Transcript entries remain selectable and are never deleted by this module.

## Tests

`LiveReaderTests` verifies live-follow intent, unseen counts, timestamp/transcript formatting, and the
immutable sharing presentation contract. Native visual, accessibility, and clean-Mac UI qualification are
tracked separately in `Docs/Testing.md`.
