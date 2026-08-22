# VADWebRTC

## Purpose

Adapts the proven WebRTC VAD to `VoiceActivityClassifying` and preserves the
deployed church-translation energy fallback for music-adjacent speech.

## Public API

- `WebRTCVoiceActivityClassifier`
- `WebRTCVoiceActivityConfiguration`
- `WebRTCVADMode`
- `WebRTCVoiceActivityClassifierError`

## Dependencies

Depends only on `VADAPI` and the isolated `WebRTCVADC` adapter. The composition
root injects it into `VADCore`; no business module imports the native target.

## Threading Model

Each classifier owns one opaque libfvad allocation and mutable noise estimate.
It must have one actor owner; `CalibratedVoiceActivityDetector` provides that
ownership in production.

## Failure Modes

Initialization reports invalid settings, native allocation failure, or rejected
native configuration. Production is deliberately fixed to 16 kHz mono and 20
ms (320-sample) frames. `classify` throws typed invalid-frame, non-finite-sample,
and native-processing failures. The protocol witness fails loudly if `VADCore`
ever violates that invariant; `VADCore` pads its one final partial window.

## Tests

`VADWebRTCTests` covers defaults, typed validation, native silence decisions,
energy fallback, reset, and repeated instance lifetimes. The environment-gated
real-sermon replay in `VADCoreTests` qualifies the composed provider.

## Qualification Evidence

The pinned libfvad implementation produced zero decision mismatches against
`webrtcvad-wheels` 2.0.14, mode 2, across 725,722 consecutive 20 ms frames from
the four-sermon corpus; both classified 642,571 frames as voiced. The upstream
codeload archive SHA-256 is
`bf639e4a5bc37b1c90e047c42524e80a1d0cecadeb6e0a61a33580fca22a00ab`.

With the calibrated endpoint policy, the native production composition emitted
1,063 segments from 14,514 seconds of Mandarin sermon audio; 29 were under two
seconds and 366 reached the hard cap. The rejected 500 ms preferred-boundary
variant emitted 1,042/28 but forced 612 hard cuts.
