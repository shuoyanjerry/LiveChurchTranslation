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
decoding error, and encoding failure propagates from `save(_:)`.

## Tests

There is no dedicated UserDefaults adapter test target. Callers are tested with
`SettingsStore` fakes.
