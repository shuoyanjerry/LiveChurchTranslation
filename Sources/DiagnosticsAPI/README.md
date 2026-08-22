# DiagnosticsAPI

## Purpose

Defines bounded operational diagnostic values without coupling business code to a storage or logging
implementation.

## Public API

`DiagnosticSeverity`, `DiagnosticEvent`, and `DiagnosticsRecorder`.

## Dependencies

Foundation only.

## Threading Model

Events are immutable and `Sendable`; recorder operations are asynchronous.

## Failure Modes

Recording is non-throwing. Export failures are surfaced to the caller.

## Tests

Session tests use a fake recorder; `DiagnosticsCore` behavior is exercised through integration tests.
