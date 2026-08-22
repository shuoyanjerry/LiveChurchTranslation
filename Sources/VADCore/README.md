# VADCore

## Purpose

Implements classifier-driven voice activity segmentation with five-window
majority decisions, configurable pre/post-roll, and bounded speech segments.
The sermon profile holds phrases with under 3.5 seconds of voiced
audio for 950 ms and ends longer ordinary phrases after 650 ms of silence,
soft-splits utterances at least 9 seconds old at a 500 ms pause, prefers a
natural boundary after 15 seconds, and enforces a 16.5 second hard ceiling.

## Endpoint Semantics

The classifier's raw result and the five-window smoother have separate jobs.
Smoothed decisions gate speech start. Once speech is active, raw decisions
drive voiced duration, endpoint pauses, and trailing-silence trimming. This
prevents the majority window from consuming a 40 ms recovered word.

Speech activation is internal until raw voiced audio reaches `minimumVoiced`.
Only then does the detector publish `speechStarted` and reserve its sequence
number. A shorter candidate publishes neither start nor end, so normal
process/flush event streams cannot contain an orphaned start event.

Endpoint pause hysteresis ignores one isolated raw-speech frame as likely noise.
Two consecutive raw-speech frames immediately cancel the pending pause. Trim is
stricter: only the final uninterrupted raw-silence run is shortened to 280 ms.

At 15 seconds, speech remains open until three of the latest five acoustic
decisions are non-speech. This avoids treating one or two noisy frames as a
boundary while minimizing unsafe 16.5-second hard cuts. If no boundary arrives
during the 1.5-second grace period, the hard cut retains every sample and lets
continuous speech start the next segment.

## Public API

`CalibratedVoiceActivityDetector` accepts any `VoiceActivityClassifying`
implementation. `AdaptiveEnergyVoiceActivityDetector` remains a compatibility
name and built-in fallback. Rolling buffers, timing helpers, and the state
machine remain internal.

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

Unit tests exercise all calibrated thresholds, isolated-noise and two-frame
recovery behavior, post-roll trimming, preferred-boundary and hard-cap reasons,
continuation, flush, reset, and invalid input handling.

The four-hour production replay emitted 1,063 segments with 29 under two
seconds. Replacing the stable post-15-second boundary with a 500 ms wait reduced
the count to 1,042 but increased unsafe hard-cap cuts from 366 to 612, so the
three-of-five acoustic boundary is retained.
