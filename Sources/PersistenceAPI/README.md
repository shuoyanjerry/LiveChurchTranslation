# PersistenceAPI

## Purpose

Defines the replaceable durable transcript-store boundary and the summary value
used to enumerate saved sessions.

## Public API

`TranscriptStore`, `StoredSessionSummary`, and `TranscriptStoreError`.

## Dependencies

`TranscriptAPI` for session and entry values, plus Foundation for identifiers,
dates, URLs, and localized errors.

## Threading Model

The protocol and summary are `Sendable`; all store operations are asynchronous.
Concrete implementations own synchronization and durability semantics.

## Failure Modes

The API distinguishes a missing session from an underlying storage failure.

## Tests

`PersistenceFileSystemTests` validates the filesystem implementation through
this boundary. `SessionManagementTests` use store fakes for failure scenarios.
