# RemoteSharingFeature

## Purpose

Coordinates local sharing, pairing invitations, revocation, and presentation state.

## Public API

`LocalNetworkSharingFeature` implements `LocalSharingFeature`.

## Dependencies

Only Remote Sharing, Pairing, Transport, and Feature API protocols.

## Threading Model

An actor owns lifecycle state and observes transport/pairing event streams.

## Failure Modes

Listener and pairing failures become one fixed, payload-free presentation state; raw errors and transport
messages stop at this boundary. A viewer link is reused for the active sharing session. A transient
listener failure retains the invitation, grants, and first listener port so retry restores the same URL.
Explicitly stopping sharing or disconnecting everyone atomically revokes the invitation and every grant;
a later session must issue a new link.

## Tests

`RemoteSharingFeatureTests` exercises enable/disable, idempotent invitation presentation, raw-error
redaction, failure/retry URL stability, global revocation, and stop/restart replay rejection against the
real pairing registry.
