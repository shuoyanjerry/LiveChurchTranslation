# ASRAPI

## Purpose

Defines the replaceable speech-recognition boundary and immutable, language-scoped recognition values.
`ASRRequest.languageCode` selects the source language; the production app currently supplies Mandarin
or English.

## Public API

`ASRProvider`, `ASRRequest`, `RecognizedUtterance`, and `ASRError`.

## Dependencies

`VADAPI` for complete speech segments; Foundation for values and URLs.

## Threading Model

Protocols and values are `Sendable`; concrete providers own model and inference serialization.

## Failure Modes

Typed errors cover unavailable or unloaded models, invalid audio, filtered nonspeech,
prompt echo, pathological decoder repetition, inference failure, and cancellation.

## Tests

`ASRQwen3Tests` exercises the production adapter, and `SessionManagementTests` uses protocol fakes.
