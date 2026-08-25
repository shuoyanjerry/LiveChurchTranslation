# SettingsAPI

## Purpose

Defines the persisted application-settings value and a replaceable settings
store boundary.

## Public API

`AppSettings`, `DisplayLanguage`, `TranslationMode`, and `SettingsStore`. Display language is independent
of the two translation directions and defaults to Simplified Chinese for legacy settings.

## Dependencies

Foundation.

## Threading Model

`AppSettings` and `SettingsStore` are `Sendable`. Load and save are asynchronous;
the concrete store owns synchronization.

## Failure Modes

The API does not prescribe an error enum. Encoding, decoding, or backend errors
are propagated by the implementation.

## Tests

`SettingsAPITests` covers display conversion, defaults, compatibility decoding, round trips, and the
two-direction invariant. Session, live-reader, and remote-control tests inject settings-store fakes.
