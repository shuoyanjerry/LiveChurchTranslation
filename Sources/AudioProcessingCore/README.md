# AudioProcessingCore

## Purpose

Provides the replaceable pure-Swift implementation of `AudioProcessor`: channel
downmixing, bounded amplitudes, and streaming conversion to 16 kHz by default.

## Public API

`MonoResamplingAudioProcessor` is the sole public implementation type. All DSP
helpers remain internal.

## Dependencies

Depends only on `AudioCaptureAPI` and `AudioProcessingAPI`. It does not import
AVFoundation, UI frameworks, storage, or a model SDK.

## Threading Model

The processor is an actor. Resampling phase and timestamps have one owner and
remain continuous when capture callbacks arrive from different executors.

## Failure Modes

Construction rejects invalid output settings. Processing rejects invalid rates,
channel layouts, and non-finite samples. A device-rate change creates a clean
resampler boundary rather than mixing incompatible state.

## Tests

Unit tests cover stereo downmixing, sample-rate conversion, stream continuity,
reset behavior, clipping, and typed validation failures.
