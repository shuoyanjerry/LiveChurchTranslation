# Endpoint and Pipeline Latency Qualification

## Scope

This document defines how endpoint and Chinese-to-English display latency must
be measured. It does not claim that the current build meets the one-to-three
second sentence-end target.

## One Correlation ID, One Monotonic Timeline

Every finalized `SpeechSegment.id` is the correlation ID through ASR,
normalization, discourse resolution, translation, persistence, local rendering,
and remote projection. Durations use one injected monotonic clock. `Date` may be
recorded for operator correlation, but wall-clock subtraction is forbidden.

The future pure-Swift diagnostics API should accept immutable events only:

```swift
public struct PipelineTraceEvent: Sendable {
    public let segmentID: UUID
    public let stage: PipelineStage
    public let transition: PipelineTransition
    public let elapsedSinceSessionStart: Duration
    public let queueDepth: Int?
}
```

The recorder is an actor. Providers receive no recorder dependency; the session
orchestrator records timestamps immediately before and after calling their public
protocols. This preserves provider replaceability and captures queue wait
separately from inference.

## Required Events

For each segment record:

1. acoustic pause candidate and VAD boundary emission;
2. ASR queued, started, completed, or failed;
3. normalization and discourse-resolution completed;
4. translation queued, started, validated, completed, or failed;
5. persistence commit completed or failed;
6. transcript-buffer append;
7. first local render acknowledgement;
8. remote enqueue, socket write, and optional viewer acknowledgement.

Model identity, model hash, endpoint policy identity, segment reason, audio
duration, queue depth, retry count, device-change generation, thermal state, and
memory-pressure state belong on the trace or its session metadata.

## Endpoint Metrics

The replay harness reports `emissionLagAfterRetainedAudio`. This is useful for
detecting policy regressions, but it is not sentence-end latency: post-roll and
trimming change the retained endpoint.

True endpoint latency requires a locked evaluation set with a human timestamp
for the last intended syllable of each utterance:

`VAD emission monotonic time - human final-syllable time`

Report p50/p95/p99 per sermon and speaker, plus miss, merge, premature split,
mid-word split, and forced hard-cut rates. `maximumDuration` is only a structural
unsafe-cut proxy until those labels exist.

## End-to-End Metrics

The product latency target is measured as:

`first stable English render - human final-syllable time`

Also report these components independently:

- endpoint decision;
- ASR queue wait and inference;
- normalization/discourse processing;
- translation queue wait, inference, and validation/retry;
- persistence and local render;
- remote transport and viewer render.

RTF is inference seconds divided by input-audio seconds. Wall latency and RTF are
not interchangeable. A fast model can still miss the target behind a queue.

Failures, timeouts, filtered segments, and retries remain in the denominator.
Publish completion rate beside conditional latency percentiles; never remove a
failed slow item and call the remaining p95 an SLA.

## Qualification Matrix

Run cold and warm sessions on the minimum supported M-series configuration,
including an 8 GB M1 if it remains supported. Cover quiet close-mic speech,
church PA/reverberation, music and applause, long rhetorical pauses, code-switching,
device changes, permission denial, model-load failure, memory pressure, thermal
pressure, and a multi-hour session.

Sample resident/peak memory and thermal state at one hertz. Report each model and
policy revision/hash, corpus hashes, app commit, macOS build, hardware, power
source, and concurrency settings. No endpoint-accuracy or one-to-three-second SLA
claim is valid without this evidence bundle.
