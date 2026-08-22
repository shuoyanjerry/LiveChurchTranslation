# SettingsAPI

## Purpose

Defines the persisted application-settings value and a replaceable settings
store boundary.

## Public API

`AppSettings`, including `.defaults`, and `SettingsStore`.

## Dependencies

Swift standard library only.

## Threading Model

`AppSettings` and `SettingsStore` are `Sendable`. Load and save are asynchronous;
the concrete store owns synchronization.

## Failure Modes

The API does not prescribe an error enum. Encoding, decoding, or backend errors
are propagated by the implementation.

## Tests

Session, live-reader, and remote-control tests inject settings-store fakes. The
API target has no standalone test target.
