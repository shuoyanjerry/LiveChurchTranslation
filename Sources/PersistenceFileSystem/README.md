# PersistenceFileSystem

## Purpose

Implements durable, append-oriented source-transcript storage in per-session
directories with a manifest, JSON Lines source of truth, and readable Markdown.

The durable JSONL projection contains recognized source text, source audit, identity,
ordering, and timing only. It never encodes translated text, translation review, or
translation duration. The generated `transcript.md` identifies the source language and
renders timestamped recognized text only. Session titles and recognized text are escaped
so their content cannot create Markdown structure or raw HTML.

Manifests carry a versioned source-only content policy. Before a legacy session is listed
or loaded, the store safely and idempotently rewrites its JSONL and Markdown, committing the
new policy last. Recordings and recovery artifacts are not modified by this migration.

## Public API

`FileTranscriptStore`, an actor implementing `TranscriptStore` and initialized
with a root directory.

## Dependencies

`PersistenceAPI`, with transcript values arriving through that API, and
Foundation filesystem and JSON facilities.

## Threading Model

The store is an actor. Session creation, idempotent entry appends, loads,
finalization, migration, and enumeration are serialized per instance. Every append and
finalization applies the source-only projection. Finalization rewrites the JSON Lines source
atomically from canonical presentation order, so recovered insertions survive restart without
duplicate UI order.

## Failure Modes

Appending to an unknown session reports `sessionNotFound`. Directory, manifest,
JSONL, Markdown, encoding, decoding, and synchronization errors are wrapped as
`TranscriptStoreError.fileSystem`. A missing root yields an empty recent list.
Deletion rejects in-memory active sessions and any on-disk recording activity marker
or partial audio artifact, including checks performed through a separate store instance.

## Tests

`PersistenceFileSystemTests` covers source-only append/finalization, legacy migration,
restart-safe idempotence, source-audit round trips, injection-safe Markdown, ordering,
and filesystem failures.
They also prove that active and recoverable recording artifacts cannot be deleted.
