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
native configuration. The injected classifier rejects detector configurations
other than 16 kHz and 20 ms (320-sample) windows during construction. `classify`
throws typed invalid-frame, non-finite-sample,
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

With short hard-cap tails retained, the native production composition emitted
1,064 segments from 14,514 seconds of private Mandarin sermon audio; 30 were
under two seconds and 366 reached the hard cap. A 500 ms preferred-boundary
variant emitted 1,043/29 and reached 610 hard caps. These are structural proxies,
not manual semantic-boundary labels. Mode 3 with the same FSM emitted 1,531
segments, 150 under two seconds, and 63 hard-cap proxies; its fragmentation kept
it challenger-only. The expanded 7.6456-hour mode 2 replay emitted 2,321 segments,
156 under two seconds, and 584 hard-cap proxies. Mode 2 stable remains selected.
