# RemotePairingAPI

## Purpose

Defines pairing DTOs and separate remote-serving/Mac-management protocols without exposing the registry.

## Public API

`RemotePairingServing`, `RemotePairingManaging`, invitation/redemption/grant/authorization values, pairing
errors, and token-free `PairingAuditRecord`.

## Dependencies

`RemoteSharingAPI` only.

## Threading Model

All values are immutable and `Sendable`; every stateful operation is asynchronous.

## Failure Modes

The closed error vocabulary covers invalid, expired, used, revoked, over-capacity, and read-only cases.

## Tests

The core conformance is tested for races, expiry, revocation, role enforcement, and audit redaction.
