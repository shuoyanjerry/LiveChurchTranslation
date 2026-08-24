# AudioImportSessionAdapter

## Purpose

Adapts a selected audio file to a speech-only session while preserving its requested recognition
language, complete finalization checks, and cooperative cancellation. Import never requests or
publishes translation.

## Public API

- `ImportedAudioTranscriber` drives one injected session controller at a time.
- `ImportedAudioSettingsStore` scopes the chosen recognition language to the imported session.
- `AudioImportCompletionValidator` rejects incomplete finalization outcomes.

## Dependencies

Only `AudioCaptureAPI`, `AudioImportAPI`, `SessionManagementAPI`, and `SettingsAPI`. Concrete file
decoding and production controller construction remain in the app composition root.

## Threading Model

`ImportedAudioTranscriber` is main-actor isolated. The injected session controller owns pipeline work;
the adapter owns import task cancellation and controller lifetime.

## Failure Modes

Concurrent imports are rejected, deliberate cancellation returns quietly, and incomplete or failed
session finalization is surfaced as `AudioImportError`.

## Tests

`AudioImportSessionAdapterTests` covers speech-only processing, recognition-language isolation,
completion outcomes, and cancellation races.
