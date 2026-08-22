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

Listener and pairing failures become bounded, non-sensitive presentation states.

## Tests

`RemoteSharingFeatureTests` exercises enable/disable and invitation behavior with fakes.
