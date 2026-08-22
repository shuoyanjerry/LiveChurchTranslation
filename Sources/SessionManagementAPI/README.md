# SessionManagementAPI

## Purpose

Defines the UI-independent control, state, event, issue, and finalization values
for a live translation session.

## Public API

`LiveSessionController`, `LiveSessionPhase`, `LiveSessionIssueStage`,
`LiveSessionIssue`, `LiveSessionFinalizationOutcome`, `LiveSessionSnapshot`, and
`LiveSessionEvent`.

## Dependencies

The declared target dependencies are `AudioCaptureAPI`, `DiagnosticsAPI`,
`ModelRuntimeAPI`, and `TranscriptAPI`; Foundation supplies identifiers.

## Threading Model

The controller is `Sendable` and asynchronous. Snapshots, issues, and events are
immutable `Sendable` values delivered through `AsyncStream`.

## Failure Modes

Preparation and runtime failure can appear as `.failed`; recoverable work is
classified by stage, and finalization explicitly distinguishes saved,
unresolved, cancelled, pre-capture failure, and save-failure outcomes.

## Tests

`SessionManagementTests` exercise the API through `LiveSessionCoordinator` and
fakes. UI and remote-control tests use fake `LiveSessionController` values.
