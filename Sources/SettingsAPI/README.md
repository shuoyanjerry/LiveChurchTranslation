# SettingsAPI

## Purpose

Defines the persisted application-settings value and a replaceable settings
store boundary.

## Public API

`AppSettings`, including `.defaults`, and `SettingsStore`. `showTimestamps` defaults to `true`; legacy
encoded settings that predate the field also decode to visible timestamps.

## Dependencies

Swift standard library only.

## Threading Model

`AppSettings` and `SettingsStore` are `Sendable`. Load and save are asynchronous;
the concrete store owns synchronization.

## Failure Modes

The API does not prescribe an error enum. Encoding, decoding, or backend errors
are propagated by the implementation.

## Tests

Session, live-reader, and remote-control tests inject settings-store fakes. Live-reader tests also cover
the default, legacy decode, and hidden-value round trip for `showTimestamps`. The API target has no
standalone test target.
