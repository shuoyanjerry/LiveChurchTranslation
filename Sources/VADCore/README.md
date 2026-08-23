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

Audio continuing across the absolute cap is already confirmed speech. Its next
segment is published immediately and retained even when the final tail is shorter
than `minimumVoiced`, preventing hard-cut audio loss.

Endpoint pause hysteresis ignores one isolated raw-speech frame as likely noise.
Two consecutive raw-speech frames immediately cancel the pending pause. Trim is
stricter: only the final uninterrupted raw-silence run is shortened to 280 ms.

The same `EndpointPauseTracker` transitions passively expose 250, 300, and
400 ms candidate checkpoints through package-only
`processWithShadowEvidence`/`flushWithShadowEvidence`. The tracker emits each
threshold once and in order. It calculates the candidate end inside the actual
analysis window, records observation overshoot, and closes each reached episode
on two-frame recovery or the real segment end. It emits only for already
published speech or accepted hard-cap continuation audio; rejected speech-start
candidates remain invisible.

Source positions are monotonic `Int64` sample indexes for one capture stream.
The pre-roll buffer retains its absolute origin when trimming. Partial EOF
windows count only valid source samples, so classifier padding cannot create or
extend candidate evidence. The shadow path stores neither audio snapshots nor
unbounded event history and cannot change a production boundary decision.

At 15 seconds, speech remains open until three of the latest five acoustic
decisions are non-speech. This avoids treating one or two noisy frames as a
boundary while minimizing structural 16.5-second hard-cap events. If no boundary arrives
during the 1.5-second grace period, the hard cut retains every sample and lets
continuous speech start the next segment.

`preferredBoundarySilence` can require a longer post-15-second pause for
qualification replays. Its zero sermon default preserves the calibrated stable
three-of-five acoustic policy. With the sermon profile, a pause of 500 ms or
more after nine seconds can still close first as `.softSilence`.

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
wrong sample rates, non-finite samples, and backwards timestamps.
Overlapping or gapped frame timestamps are rejected as discontinuities; callers
must reset the stream after an intentional device-generation change. Transients
shorter than the configured voiced minimum are rejected. End-of-stream flushing
classifies one padded native window when needed but never retains or counts the
synthetic zeros as audio. It explicitly closes valid active speech.

## Tests

Unit tests exercise all calibrated thresholds, isolated-noise and two-frame
recovery behavior, post-roll trimming, preferred-boundary and hard-cap reasons,
continuation, adversarial post-15-second pause recovery, flush, reset, and
invalid input handling. Deterministic shadow tests additionally cover checkpoint
ordering, pre-roll and timestamp origins, blip recovery, independent episodes,
partial EOF, hard-cap sequence rollover, unconfirmed-speech suppression,
production-event parity, and bounded rolling storage.

After preserving short hard-cap tails, the four-hour private replay emitted
1,064 segments with 30 under two seconds. Requiring a 500 ms post-15-second wait
emitted 1,043 segments but increased the structural hard-cut proxy from 366 to
610, so neither replay supplies semantic boundary accuracy without manual labels.
Mode 3 with the identical FSM emitted 1,531 segments, 150 under two seconds, and
63 hard-cap proxies; the extra fragmentation prevents promotion without labels.
The 7.6456-hour expanded mode 2 replay emitted 2,321 segments, 156 under two
seconds, and 584 hard-cap proxies. Mode 2 stable remains the selected default.

A stratified review of 29 short segments from the expanded set found 19 readable
complete proxies, two semantically incomplete subordinate-phrase proxies, seven
ambiguous short utterances, and one silent EOF tail. These are review categories,
not human time-aligned boundary labels or an accuracy estimate.
