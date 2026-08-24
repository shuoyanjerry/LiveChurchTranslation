# RemoteProjectionCore

## Purpose

Maintains the transport-neutral, authoritative transcript projection and per-peer delivery queues. The Mac
remains the sole writer and inference host.

## Public API

`RemoteProjectionStore`, `ProjectionConfiguration`, `ProjectionError`, and the
default-off `RemoteSharingSwitch`.

## Dependencies

`RemoteSharingAPI` only. Mutation input and `RemoteProjectionUpdating` live in that API target so session
bridges never import this concrete store.

## Threading Model

The store is an actor. `connect` captures a snapshot and installs the peer queue in one actor turn, forming
a snapshot/live barrier. Every later mutation is queued after that snapshot revision.

## Failure Modes

Oversized text is rejected. Snapshots are bounded by entry count and UTF-8 text bytes; per-peer queues are
also bounded. A slow peer receives one
`resyncRequired` envelope instead of unbounded buffered deltas. Upserts are keyed by entry identity, so a
late result with a lower sermon sequence is retained and sorted correctly.
The authoritative snapshot retains the current source and target languages even when it has no entries.
Projected entries retain optional session-relative `startedMilliseconds`; resync and slow-peer handling do
not synthesize or discard that timing metadata.

## Tests

Tests cover pre-entry language metadata, timestamp wire round trips, late lower sequences, the
snapshot/live barrier, bounded snapshots, and slow-peer resync.
