# TranscriptCore

## Purpose

Implements the in-memory live transcript buffer, deterministic entry creation,
session lifecycle, and asynchronous transcript events.

## Public API

`LiveTranscriptBuffer`, an actor implementing `TranscriptBuffer`.

## Dependencies

`TranscriptAPI`, with direct `ASRAPI` and `TranslationAPI` types used to build
entries, plus Foundation.

## Threading Model

The actor serializes session mutation and event-continuation ownership. Events
are yielded to independent `AsyncStream` consumers.

## Failure Modes

Entry construction throws when no session is active. Append is a no-op and
finish returns `nil` without an active session. The buffer is in-memory and does
not provide durability.

## Tests

`TranscriptCoreTests` covers begin, entry mapping and sequencing, source audit,
append, snapshot, finish, and event publication.
