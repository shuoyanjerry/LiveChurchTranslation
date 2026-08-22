# RemoteControlAPI

## Purpose

Defines the complete and deliberately tiny remote mutation surface. Remote devices can only request
Start or Stop. Model, microphone, glossary, shutdown, history, and export operations are unrepresentable.

## Public API

`RemoteControlRequest`, `RemoteControlResult`, `RemoteControlAuthorization`,
`RemoteSessionCommandHandling`, and `RemoteControlPolicy`.

## Dependencies

`RemoteSharingAPI` for peer and role identities.

## Threading Model

Values are immutable and `Sendable`; handlers are asynchronous.

## Failure Modes

Requests can be rejected for authorization, a stale expected revision, disabled sharing, or local session
unavailability. Callers must render the authoritative state received after a command, not predict it.

## Tests

Viewer denial and the intentionally closed command vocabulary are covered by pairing/control tests.
