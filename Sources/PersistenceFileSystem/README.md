# PersistenceFileSystem

## Purpose

Implements durable, append-oriented transcript storage in per-session
directories with a manifest, JSON Lines source of truth, and readable Markdown.

The generated `transcript.md` uses Chinese-localized structural labels but is direction-neutral. Its header
identifies the live meeting or imported audio, includes the optional session title, selected source/target
languages, start and end times, and integrity state. Every passage has a precise time range and explicit
`译文` and `识别原文` labels in either supported direction. Session titles, recognized source text, and
translations are escaped before Markdown rendering so their content cannot create headings, quotations,
lists, fenced blocks, links, or raw HTML.

## Public API

`FileTranscriptStore`, an actor implementing `TranscriptStore` and initialized
with a root directory.

## Dependencies

`PersistenceAPI`, with transcript values arriving through that API, and
Foundation filesystem and JSON facilities.

## Threading Model

The store is an actor. Session creation, idempotent entry appends, loads,
finalization, and enumeration are serialized per instance. Finalization rewrites
the JSON Lines source atomically from the canonical presentation order supplied by
the session, so recovered insertions survive restart without duplicate UI order.

## Failure Modes

Appending to an unknown session reports `sessionNotFound`. Directory, manifest,
JSONL, Markdown, encoding, decoding, and synchronization errors are wrapped as
`TranscriptStoreError.fileSystem`. A missing root yields an empty recent list.
Deletion rejects in-memory active sessions and any on-disk recording activity marker
or partial audio artifact, including checks performed through a separate store instance.

## Tests

`PersistenceFileSystemTests` covers session creation, restart-safe idempotent
append, loading, structured and injection-safe Markdown generation, ordering, and
filesystem failures.
They also prove that active and recoverable recording artifacts cannot be deleted.
