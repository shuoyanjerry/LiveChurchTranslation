# AudioImportAPI

## Purpose

Defines the app-facing contract for transcribing a local audio file or a supported video's audio
track in its selected source language. Imported media never enters translation; bilingual processing
remains exclusive to live sessions.

## Public API

- `AudioImporting` starts or cancels one import.
- `AudioImportError` carries concise user-facing failure categories.

## Dependencies

`SettingsAPI` supplies the internal mode used to select the recognition language. Its target-language
field is not an import behavior. The contract does not import any capture, session, storage, or model
implementation.

## Threading Model

Conforming implementations own their concurrency and cancellation state. Calls are asynchronous and
the protocol is `Sendable`.

## Failure Modes

Cancellation is distinct from processing failure so the interface can remain quiet after deliberate
user cancellation.

## Tests

The contract is exercised by `AudioImportSessionAdapterTests` and `LiveReaderTests` through injected
fakes.
