# RemoteSharingAPI

## Purpose

Defines immutable wire-safe values and narrow projection/sharing protocols. It does not know about UI,
transport, persistence, models, or the local session implementation.

## Public API

`RemoteRole`, `RemotePeer`, `RemoteProjectionSnapshot`, `RemoteProjectionEnvelope`,
`RemoteProjectionProviding`, and `RemoteSharingControlling`.

Projection snapshots and live state updates carry the session language pair independently of transcript
entries, allowing every listener to receive the correct target-language presentation before the first
sentence is ready.
Each projected entry may also carry `startedMilliseconds`, a session-relative passage offset. The field is
optional for wire compatibility; presentation code may hide it without changing the authoritative entry.

## Dependencies

Foundation only. No other project target.

## Threading Model

Every public value is immutable and `Sendable`. Protocol methods are asynchronous so implementations can
use actors without exposing ownership.

## Failure Modes

The API does not perform I/O. Implementations report transport and authorization failures at their own
boundary.

## Tests

Codable round trips, language metadata, and optional timestamp transport are covered through projection,
adapter, and transport tests.
