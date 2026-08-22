# LoggingAPI

## Purpose

Defines structured log values and the replaceable application logging boundary
without selecting a logging backend.

## Public API

`LogLevel`, `LogRecord`, and `AppLogger`.

## Dependencies

Foundation only, for timestamps and coding.

## Threading Model

Records and the logger protocol are `Sendable`. `write(_:)` is synchronous; a
concrete backend is responsible for safe concurrent use.

## Failure Modes

The boundary intentionally has no throwing operation. Backends must not rely on
callers to recover from a logging failure.

## Tests

Session and diagnostics tests inject logger fakes. This API target has no
standalone test target.
