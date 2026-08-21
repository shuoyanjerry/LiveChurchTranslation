# VADCore

## Purpose

Implements local voice activity detection with adaptive RMS noise tracking,
fixed analysis windows, configurable pre-roll, a 650 ms default silence
hangover, and bounded-duration speech segments.

## Public API

`AdaptiveEnergyVoiceActivityDetector` is the only public implementation. Its
classifier, rolling buffer, timing helpers, and state machine remain internal.

## Dependencies

Depends only on `VADAPI` (which carries the `AudioProcessingAPI` value type). It
does not import AVFoundation, UI frameworks, persistence, or a model SDK.

## Threading Model

The detector is an actor. All adaptive noise and segmentation state has one
owner; callers may safely submit frames from concurrent tasks.

## Failure Modes

Initialization rejects unsafe timing or threshold settings. Processing reports
wrong sample rates, non-finite samples, and backwards timestamps. End-of-stream
flushing explicitly closes active speech instead of dropping it.

## Tests

Unit tests exercise delayed speech activation, the 650 ms silence boundary,
noise-floor adaptation, maximum-duration splitting, flush, reset, and invalid
input handling.
