# AudioCaptureAVFoundation

## Purpose

Implements `AudioCaptureProvider` with AVFoundation capture and Core Audio device
discovery/selection. It emits immutable interleaved Float32 frames.

## Public API

`AVFoundationAudioCaptureProvider` is the sole public implementation type.

## Dependencies

`AudioCaptureAPI` plus the system AVFoundation, AudioToolbox, and CoreAudio
frameworks. No third-party runtime is used.

## Threading model

An actor owns the engine and active continuation. The real-time tap only copies
PCM samples into an immutable value and yields it to `AsyncThrowingStream`.

## Failure modes

Permission denial, disappearing inputs, malformed formats, Core Audio selection
errors, and AVAudioEngine startup errors are surfaced to the caller or stream.

## Tests

The adapter is designed for hardware integration tests on a microphone-enabled
Mac. Pure resampling and VAD behavior are tested in their respective modules.
