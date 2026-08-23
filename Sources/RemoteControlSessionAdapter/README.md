# RemoteControlSessionAdapter

## Purpose

Applies the local recording-consent boundary to remote commands. Start always fails closed because a remote
device cannot accept the Mac recording notice. A locally authorized operator may stop an active session.

## Public API

`LiveSessionRemoteMutationTarget`, injected as `RemoteSessionMutationTarget`.

## Dependencies

`AudioCaptureAPI`, `RemoteControlAPI`, `SessionManagementAPI`, and `SettingsAPI` only.

## Threading Model

The immutable adapter forwards stop asynchronously to an injected `Sendable` session controller.

## Failure Modes

Start returns a stable local-authorization error. Stop rejects when no session is active. Session runtime
state remains authoritative and flows back through the projection.

## Tests

Focused tests verify remote Start rejection, authorized Stop forwarding, and inactive-session rejection.
