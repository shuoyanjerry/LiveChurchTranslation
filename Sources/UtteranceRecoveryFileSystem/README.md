# UtteranceRecoveryFileSystem

## Purpose

Provides the durable filesystem adapter for `UtteranceRecoveryStore`. Each VAD
segment is committed as a private record directory containing IEEE-float mono
WAV audio and versioned JSON metadata.

## Public API

- `FileUtteranceRecoveryStore`: actor-isolated stage, demand-driven paged
  recovery, legacy one-shot recovery, and complete adapter.
- Terminal quality rejections retain a typed receipt under the private
  per-session `rejected` directory and never reenter the retry queue.
- `UtteranceRecoveryLimits`: injected sample-count, file-size, metadata-size,
  and sample-rate bounds.

## Dependencies

Depends on `UtteranceRecoveryAPI` and `VADAPI`. It does not depend on session
management, ASR, translation, transcript storage, logging, or UI modules.

## Threading Model

The public store is an actor. It owns `FileManager`, directory mutation, and its
injected clock; concurrent callers are serialized without global state.

## Failure Modes

Validation fails before allocation or disk writes. Root, session, per-session
artifact, and total-recovery counts are bounded. Cross-session discovery accepts
only canonical UUID-named, non-symbolic-link directories. Audio and metadata are first
written to private temporary files, synchronized, renamed inside a staging
directory, and committed by an atomic same-directory rename. Completion first
renames to a tombstone, preventing a completed record from being replayed after
a crash. Schema v1 predates an explicit processing topology and is resolved from
durable transcript evidence during replay; new schema v2 records declare one atomic
transcript entry per VAD segment. Terminal
rejection writes a stable receipt before moving the record
out of `pending`; its redundant segment WAV is then removed because the complete
meeting recording remains authoritative. Corrupt, partial, orphaned, and oversized artifacts move to a private
quarantine directory without exposing sample contents.
Paged recovery first indexes only bounded metadata and paths. WAV payloads are
decoded on iterator demand, never more than the requested page size, and each
page is released before the session orchestrator asks for the next one.

## Tests

`UtteranceRecoveryFileSystemTests` verify single- and multi-session restart
recovery, exact metadata, deterministic ordering, bounded enumeration, atomic
completion cleanup, malformed/oversized/non-finite rejection, and quarantine.
Paging tests exercise 128 committed records, strict page/sample ceilings,
demand-time WAV decoding, cross-session ordering, and continued recovery after
corrupt records are quarantined.
