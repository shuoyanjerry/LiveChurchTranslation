# RemotePairingCore

## Purpose

Owns invitation, pairing, grant, expiry, revocation, role, and security-audit state. A private network is
never treated as authorization.

## Public API

`PairingRegistry`, `PairingInvitation`, `PairingRedemption`, `PairingGrant`,
`PairingConfiguration`, and `PairingAuditRecord`.

## Dependencies

`RemoteSharingAPI`, `RemotePairingAPI`, Foundation, CryptoKit, and Security. Token generation is injected for
deterministic tests.

## Threading Model

`PairingRegistry` is an actor. Invitation redemption, grant-capacity admission, and operator single-use
marking occur in one actor turn. A viewer invitation can therefore admit multiple listeners concurrently
without oversubscribing the configured grant limit.

## Failure Modes

Viewer invitations are read-only, reusable, and held only in memory until sharing stops or the app exits.
Viewer grants share that session lifetime so an already-open reader cannot expire mid-meeting. Operator
invitations remain single-use and expire after at most five minutes; operator grants expire within 24 hours.
Global revocation removes every invitation and grant atomically; restarting sharing issues a fresh secret,
so an old link cannot be replayed. Grant credentials are scoped to the server-observed client binding and
stored only as SHA-256 hashes. Credentials, client bindings, and transcript text never enter the bounded
audit log.

## Tests

Tests cover concurrent viewer redemption, operator redemption races, per-redemption capacity, session
revocation and secret rotation, client-binding replay denial, expiry, viewer mutation denial, 256-bit
credentials, coding output, and audit redaction.
