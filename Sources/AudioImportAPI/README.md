# AudioImportAPI

## Purpose

Defines the app-facing contract for importing a local audio file into the same bilingual session
pipeline used by live translation.

## Public API

- `AudioImporting` starts or cancels one import.
- `AudioImportError` carries concise user-facing failure categories.

## Dependencies

`SettingsAPI` supplies the selected translation direction. The contract does not import any capture,
session, storage, or model implementation.

## Threading Model

Conforming implementations own their concurrency and cancellation state. Calls are asynchronous and
the protocol is `Sendable`.

## Failure Modes

Cancellation is distinct from processing failure so the interface can remain quiet after deliberate
user cancellation.

## Tests

The contract is exercised by `AudioImportSessionAdapterTests` and `LiveReaderTests` through injected
fakes.
