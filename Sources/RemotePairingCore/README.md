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

`PairingRegistry` is an actor. Invitation redemption and single-use marking occur in one actor turn, so two
devices cannot redeem the same invitation concurrently.

## Failure Modes

Invitations expire after at most five minutes and are single-use. Grant credentials are stored only as
SHA-256 hashes, expire within 24 hours, and can be individually or globally revoked. Credentials and
transcript text never enter the bounded audit log.

## Tests

Tests cover redemption races, expiry, revocation, viewer mutation denial, 256-bit credentials, and audit
redaction.
