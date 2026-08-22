# RemoteWebAssetsAPI

## Purpose

Defines the immutable web-asset value and the narrow provider boundary used by transport.

## Public API

`RemoteWebAsset` and `RemoteWebAssetProviding`.

## Dependencies

Foundation only.

## Threading Model

Providers are `Sendable`; returned asset bytes are immutable values.

## Failure Modes

Unknown paths return `nil` and are handled as 404 by transport.

## Tests

The bundled implementation is tested through this protocol.
