# LoggingOSLog

## Purpose

Adapts application log records to Apple's unified logging system.

## Public API

`UnifiedLogger`, an `AppLogger` initialized with an OSLog subsystem.

## Dependencies

`LoggingAPI` and Apple's `OSLog` framework.

## Threading Model

`UnifiedLogger` is an immutable `Sendable` value. Each write creates a category
logger and delegates synchronization to OSLog.

## Failure Modes

Logging is nonthrowing by contract. Metadata is sorted and rendered as public
text; this adapter does not redact values supplied by the caller.

## Tests

There is no dedicated OSLog adapter test target. Callers are tested with
`AppLogger` fakes.
