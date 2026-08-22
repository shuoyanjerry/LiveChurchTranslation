# RemoteSharingAPI

## Purpose

Defines immutable wire-safe values and narrow projection/sharing protocols. It does not know about UI,
transport, persistence, models, or the local session implementation.

## Public API

`RemoteRole`, `RemotePeer`, `RemoteProjectionSnapshot`, `RemoteProjectionEnvelope`,
`RemoteProjectionProviding`, and `RemoteSharingControlling`.

## Dependencies

Foundation only. No other project target.

## Threading Model

Every public value is immutable and `Sendable`. Protocol methods are asynchronous so implementations can
use actors without exposing ownership.

## Failure Modes

The API does not perform I/O. Implementations report transport and authorization failures at their own
boundary.

## Tests

Codable round trips are covered through projection and transport tests.
