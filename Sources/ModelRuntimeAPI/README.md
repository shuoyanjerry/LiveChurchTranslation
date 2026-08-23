# ModelRuntimeAPI

## Purpose

Defines immutable model identity, manifest metadata, runtime state, local
location storage, and status-reporting boundaries.

## Public API

`ModelID`, `ModelDescriptor`, `ModelRuntimeState`, `ModelRuntimeStatus`,
`ModelLocationStore`, `ModelRuntimeReporting`, and
`ModelRuntimeHealthChecking`. Runtime adapters use the health boundary for a
lightweight in-memory/process check before a later session reuses a loaded
model; it does not validate or hash model files.

## Dependencies

Foundation only, for URLs and coding support.

## Threading Model

All values and protocols are `Sendable`. Store, reporter, and health operations
are asynchronous; implementations own mutable state and event-stream
lifetimes.

## Failure Modes

Runtime failure is represented by `ModelRuntimeState.failed`. A false health
result asks the owning coordinator to reload the runtime from its verified
local location. Location registration and removal may throw
implementation-specific storage errors.

## Tests

`ModelDownloadHTTPTests` and `SessionManagementTests` exercise these boundaries
with concrete stores or fakes. There is no standalone API test target.
