# RemoteSharingFeatureAPI

## Purpose

Defines immutable presentation state and user intent for optional local-network reading.

## Public API

`LocalSharingFeature`, `LocalSharingViewState`, invitation and peer value types.

## Dependencies

Pure Swift/Foundation values only; no transport, UI, or model implementation.

## Threading Model

The feature is `Sendable`; state is delivered through an `AsyncStream`.

## Failure Modes

All implementation failures collapse to a fixed, payload-free presentation state. Raw errors, transport
messages, paths, and credentials are never exposed as state.

## Tests

Concrete behavior is tested in `RemoteSharingFeatureTests`.
