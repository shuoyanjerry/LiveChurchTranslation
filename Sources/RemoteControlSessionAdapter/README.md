# RemoteControlSessionAdapter

## Purpose

Maps the intentionally tiny remote mutation boundary to the existing live-session API. It reads the current
Mac-selected audio input at Start time; remote clients cannot choose or change that input.

## Public API

`LiveSessionRemoteMutationTarget`, injected as `RemoteSessionMutationTarget`.

## Dependencies

`AudioCaptureAPI`, `RemoteControlAPI`, `SessionManagementAPI`, and `SettingsAPI` only.

## Threading Model

The immutable adapter forwards asynchronous calls to injected `Sendable` protocols.

## Failure Modes

A settings-load error rejects Start as unavailable. Session runtime failures remain authoritative session
state and flow back through the projection.

## Tests

Focused tests verify current-input selection, Start, Stop, and settings failure without concrete services.
