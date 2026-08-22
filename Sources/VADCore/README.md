# VADCore

## Purpose

Implements local voice activity detection with adaptive RMS noise tracking,
five-window majority decisions, configurable pre/post-roll, and bounded speech
segments. The sermon profile ends ordinary phrases after 650 ms of silence,
soft-splits utterances longer than 14 seconds at a 180 ms pause, and enforces a
27 second hard ceiling.

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
wrong sample rates, non-finite samples, and backwards timestamps. Transients
shorter than the configured voiced minimum are rejected. End-of-stream flushing
explicitly closes valid active speech instead of dropping it.

## Tests

Unit tests exercise voting, minimum voiced duration, post-roll trimming, the
650 ms silence boundary, long-sentence soft splitting, maximum-duration
splitting, flush, reset, and invalid input handling.
