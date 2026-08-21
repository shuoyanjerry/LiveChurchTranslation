# VADAPI

## Purpose

Defines the replaceable boundary between normalized audio and bounded speech
segments consumed by ASR.

## Public API

- `VoiceActivityDetector`: process, flush, and reset lifecycle.
- `VoiceActivityEvent`: explicit speech-start and speech-end events.
- `SpeechSegment`: immutable samples, timing, sequence, and close reason.
- `VoiceActivityConfiguration` and `VoiceActivityError`.

## Dependencies

Depends only on `AudioProcessingAPI`; there is no model, UI, or storage coupling.

## Threading Model

Protocols and values are `Sendable`. Implementations serialize mutable adaptive
state internally, normally with an actor.

## Failure Modes

Bad configuration, wrong sample rate, non-finite samples, and backwards stream
timestamps are explicit typed failures. `flush()` is loss-aware and closes an
active segment.

## Tests

`VADCoreTests` verify noise adaptation, start/end events, the 650 ms default
hangover, maximum-duration splitting, flushing, and reset behavior.
