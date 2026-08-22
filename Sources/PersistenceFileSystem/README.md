# PersistenceFileSystem

## Purpose

Implements durable, append-oriented transcript storage in per-session
directories with a manifest, JSON Lines source of truth, and readable Markdown.

## Public API

`FileTranscriptStore`, an actor implementing `TranscriptStore` and initialized
with a root directory.

## Dependencies

`PersistenceAPI`, with transcript values arriving through that API, and
Foundation filesystem and JSON facilities.

## Threading Model

The store is an actor. Session creation, idempotent entry appends, loads,
finalization, and enumeration are serialized per instance.

## Failure Modes

Appending to an unknown session reports `sessionNotFound`. Directory, manifest,
JSONL, Markdown, encoding, decoding, and synchronization errors are wrapped as
`TranscriptStoreError.fileSystem`. A missing root yields an empty recent list.

## Tests

`PersistenceFileSystemTests` covers session creation, restart-safe idempotent
append, loading, Markdown generation, ordering, and filesystem failures.
