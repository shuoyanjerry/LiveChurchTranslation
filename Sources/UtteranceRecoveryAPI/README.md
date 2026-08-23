# UtteranceRecoveryAPI

## Purpose

Defines the crash-safe handoff between a completed VAD speech segment and the
ASR/translation pipeline. A caller stages first, performs inference second, and
marks completion only after the transcript is durable.

## Public API

- `UtteranceRecoveryStore`: stage, bounded all-session recovery pages, legacy
  one-shot recovery, and complete lifecycle.
- `PendingUtteranceID` and `PendingUtteranceRecord`: immutable retry identity and
  exact `SpeechSegment` data.
- `UtteranceRecoveryBatch`: ordered recoverable records plus quarantined-artifact
  evidence.
- `UtteranceRecoveryError`: typed validation and durability failures.

## Dependencies

Depends only on `VADAPI`. It has no model, UI, logging, or filesystem dependency.

## Threading Model

All values and protocols are `Sendable`. Implementations own mutation and
serialization; callers never receive a shared mutable buffer.
`UtteranceRecoveryPages` is demand-driven and single-pass. Filesystem adapters
decode at most the requested number of records per page. The protocol default
bridges existing adapters through the legacy one-shot method during migration.
Paged records are session-contiguous: sessions follow their earliest staging
time with UUID tie-breaking, and records within a session follow source sequence
with segment UUID tie-breaking.

## Failure Modes

Empty, oversized, non-finite, badly timed, or unsupported-rate segments fail
explicitly. Duplicate identities, missing completion records, bounded recovery
scan limits, and filesystem operations are typed errors. Corrupt on-disk
artifacts are quarantined and reported separately from healthy records.

## Tests

The filesystem adapter tests process-restart reload, sequence ordering,
completion deletion, validation bounds, and corrupt-artifact quarantine.
