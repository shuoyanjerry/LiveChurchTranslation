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

Logging is nonthrowing by contract. Dynamic messages and metadata values are
private OSLog fields by default. Subsystem, category, and level remain stable
routing data and must not contain user content.

## Tests

`LoggingOSLogTests` verifies deterministic payload formatting and enforces the
single private OSLog interpolation policy at the source boundary.
