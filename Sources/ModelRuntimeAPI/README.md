# ModelRuntimeAPI

## Purpose

Defines immutable model identity, manifest metadata, runtime state, local
location storage, and status-reporting boundaries.

## Public API

`ModelID`, `ModelDescriptor`, `ModelRuntimeState`, `ModelRuntimeStatus`,
`ModelLocationStore`, and `ModelRuntimeReporting`.

## Dependencies

Foundation only, for URLs and coding support.

## Threading Model

All values and protocols are `Sendable`. Store and reporter operations are
asynchronous; implementations own mutable state and event-stream lifetimes.

## Failure Modes

Runtime failure is represented by `ModelRuntimeState.failed`. Location
registration and removal may throw implementation-specific storage errors.

## Tests

`ModelDownloadHTTPTests` and `SessionManagementTests` exercise these boundaries
with concrete stores or fakes. There is no standalone API test target.
