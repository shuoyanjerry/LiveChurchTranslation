# RemoteControlCore

## Purpose

Enforces operator authorization and expected revisions for the closed command vocabulary independently
of local session policy. The production adapter rejects Start and permits only Stop.

## Public API

`RevisionCheckedRemoteCommandHandler`, injected through `RemoteSessionCommandHandling`.

## Dependencies

`RemoteControlAPI` and `RemoteSharingAPI` only.

## Threading Model

The handler is an actor. It reserves the next revision before awaiting a local mutation, preventing two
concurrent commands with the same expected revision from both succeeding. Recent request IDs are bounded
and replay-safe.

## Failure Modes

Disabled sharing, viewer role, stale revision, and target failure return explicit rejections. No error is
silently converted into success.

## Tests

Tests cover viewer denial, stale revisions, same-revision races, request replay, and target failure.
