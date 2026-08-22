# RemoteTransportAPI

## Purpose

Defines listener lifecycle without exposing Network.framework or the concrete server to sharing features.

## Public API

`RemoteTransportServing`, `RemoteTransportConfiguration`, `RemoteEndpoint`, status, events, and lifecycle
errors.

## Dependencies

Foundation and the pure-value `RemoteDiscoveryAPI`.

## Threading Model

Lifecycle operations are asynchronous; values are immutable and `Sendable`.

## Failure Modes

Start rejects unsafe configuration or an already-running listener and surfaces a bounded listener message.

## Tests

The Network.framework implementation is exercised through this boundary with start/stop smoke tests.
