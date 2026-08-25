# SettingsUserDefaults

## Purpose

Persists `AppSettings` as encoded data in a configurable `UserDefaults` suite.

## Public API

`UserDefaultsSettingsStore`, initialized with an optional suite name and storage
key.

## Dependencies

`SettingsAPI` and Foundation's `UserDefaults` and JSON coding facilities.

## Threading Model

The store is an actor, serializing loads and saves through one instance.

## Failure Modes

A missing value returns `AppSettings.defaults`. Invalid stored data throws a
decoding error, and encoding failure propagates from `save(_:)`. Settings encoded before
the timestamp or display-language fields existed inherit their documented defaults when decoded.

## Tests

`SettingsUserDefaultsTests` verifies persistence across independent store instances. Callers also use
`SettingsStore` fakes for feature-level behavior.
