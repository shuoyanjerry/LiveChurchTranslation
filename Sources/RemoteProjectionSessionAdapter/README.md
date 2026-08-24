# RemoteProjectionSessionAdapter

## Purpose

Projects live-session state and transcript deltas into the authenticated LAN reader boundary.
The session language pair is projected at session start, before the first transcript entry.
Each transcript delta carries its session-relative start milliseconds so the remote reader can present the
same timing as the Mac without receiving recording files or wall-clock metadata.

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

Adapter tests cover initial language metadata, timestamp preservation, snapshots, deltas, session resets,
and error redaction.
