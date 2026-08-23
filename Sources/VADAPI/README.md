# VADAPI

## Purpose

Defines the replaceable boundary between normalized audio and bounded speech
segments consumed by ASR.

## Public API

- `VoiceActivityDetector`: process, flush, and reset lifecycle.
- `VoiceActivityClassifying`: replaceable frame-level speech decisions and
  explicit analysis-window compatibility validation.
- `VoiceActivityEvent`: explicit speech-start and speech-end events.
- `SpeechSegment`: immutable samples, timing, sequence, and close reason,
  including long-utterance soft-silence, preferred-maximum, and hard-cap
  boundaries.
- `VoiceActivityConfiguration` and `VoiceActivityError`.

## Package Shadow Evidence

The public detector protocol and `VoiceActivityEvent` are unchanged. Package
targets may use `ObservedVoiceActivityBatch` and `CandidatePauseTraceEvent` to
observe native endpoint-pause checkpoints without granting them boundary
authority. A reached checkpoint carries its speech sequence, independent pause
episode, 250/300/400 ms threshold, exact `Int64` source-sample positions,
sample-clock timestamps, analysis window, and overshoot. A resolution records
stable speech resumption or the production segment-end reason.

These values are package-scoped so evaluation code can join evidence while app
and external clients remain on the production lifecycle API.

## Sermon Profile

The calibrated `.sermon` profile uses 20 ms analysis windows and a five-window,
three-vote speech-start decision. It keeps 240 ms of pre-roll and 280 ms of
post-roll, requires 240 ms of raw voiced audio, and applies these boundaries:

- phrases with under 3.5 seconds of voiced audio: 950 ms of endpoint silence;
- longer ordinary phrases: 650 ms of endpoint silence;
- segments at least 9 seconds old: a 500 ms pause may soft-split;
- segments at least 15 seconds old: the next stable three-of-five acoustic
  non-speech decision ends with `.maximumBoundary`;
- uninterrupted segments: a 1.5 second grace period ends at the absolute
  16.5 second `.maximumDuration` cap.

`preferredMaximumSegment` names the 15 second preference explicitly.
`maximumSegment` remains as a source-compatible property and initializer label.
`maximumBoundaryGrace` controls the wait from the preference to the hard cap.

`speechStarted` is published after `minimumVoiced` is confirmed. Audio that
continues across an accepted hard cap is already confirmed and starts its next
segment immediately, even if that final tail is shorter than `minimumVoiced`.
Other candidates that end earlier emit no lifecycle events; accepted candidates
retain their original timestamp and close at a boundary or `flush()`.

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

`VADCoreTests` verify the calibrated defaults, raw/smoothed decision separation,
pause recovery, exact post-roll trimming, preferred and absolute maximums,
minimum voiced audio, partial-window flushing, reset behavior, and shadow-event
parity with the production lifecycle path.
