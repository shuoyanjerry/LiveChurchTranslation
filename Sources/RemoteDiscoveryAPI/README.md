# RemoteDiscoveryAPI

## Purpose

Defines pure, safe Bonjour metadata without exposing Network.framework listener ownership.

## Public API

`RemoteBonjourDescriptor` and `RemoteBonjourDescribing`.

## Dependencies

Foundation only. No Apple networking framework and no implementation target.

## Threading Model

The immutable descriptor crosses module boundaries as a `Sendable` value. Transport retains listener
ownership and performs framework conversion internally.

## Failure Modes

Discovery failure must never alter authentication or listener authorization.

## Tests

The concrete descriptor and listener attachment are tested in `RemoteDiscoveryBonjourTests`.
