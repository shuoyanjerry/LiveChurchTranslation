# AudioProcessingAPI

## Purpose

Defines the stable boundary that converts captured, interleaved audio into a
finite mono stream at a model-compatible sample rate.

## Public API

- `AudioProcessor`: asynchronous processing and stream reset protocol.
- `AudioProcessingConfiguration`: immutable target-rate and amplitude policy.
- `ProcessedAudioFrame`: immutable mono samples plus stream timestamp.
- `AudioProcessingError`: explicit validation failures.

## Dependencies

Depends only on `AudioCaptureAPI`; it has no UI, persistence, or model-runtime
dependency.

## Threading Model

Values are `Sendable`. Implementations own serialization and any stream state.

## Failure Modes

Invalid rates, channel layouts, configuration, and non-finite samples are
reported as typed errors. Empty, valid frames are allowed.

## Tests

Contract behavior is exercised through the `AudioProcessingCore` unit tests and
through session integration tests.
