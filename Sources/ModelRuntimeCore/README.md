# ModelRuntimeCore

## Purpose

Provides local-directory model lookup and an in-memory runtime-status reporter
behind the `ModelRuntimeAPI` protocols.

## Public API

`LocalModelLocationStore` and `ModelRuntimeReporter`.

## Dependencies

`ModelRuntimeAPI` and Foundation filesystem and asynchronous-stream facilities.

## Threading Model

Both implementations are actors. Location caching, runtime states, and stream
continuations are serialized per instance.

## Failure Modes

Missing or non-directory locations are ignored by lookup and rejected during
registration. Reporter state updates are nonthrowing; event streams end when
their consumers terminate.

## Tests

There is no dedicated `ModelRuntimeCoreTests` target. Download and session tests
exercise the protocol behavior with concrete instances or fakes.
