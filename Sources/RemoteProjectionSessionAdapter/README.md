# RemoteProjectionSessionAdapter

## Purpose

Projects live-session state and transcript deltas into the authenticated LAN reader boundary.

## Public API

`LiveSessionProjectionAdapter.start()` and `stop()`.

## Dependencies

Only `SessionManagementAPI`, `TranscriptAPI`, and `RemoteSharingAPI`.

## Threading Model

An actor owns the observation task and idempotent projected-entry identities.

## Failure Modes

Projection size rejection skips only the unsafe remote update; local transcripts remain authoritative.
Remote messages intentionally redact local runtime details.

## Tests

Adapter tests cover initial snapshots, deltas, session resets, and error redaction.
