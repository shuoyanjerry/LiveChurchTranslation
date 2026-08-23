import VADAPI

extension SpeechWindowSegmenter {
    mutating func beginSpeech(
        with samples: [Float],
        at timestamp: Duration,
        sourceSampleStart: Int64,
        voicedSampleCount: Int,
        isConfirmedContinuation: Bool = false
    ) -> ObservedVoiceActivityBatch {
        let sequence = startPublication.nextSequenceNumber
        activeSpeech = ActiveSpeech(
            seed: ActiveSpeechSeed(
                sequenceNumber: sequence,
                samples: samples,
                startedAt: timestamp,
                startedAtSourceSample: sourceSampleStart,
                voicedSampleCount: voicedSampleCount,
                isConfirmedContinuation: isConfirmedContinuation
            ),
            thresholds: thresholds
        )
        startCandidate.reset()
        preRoll.removeAll()
        guard let speech = activeSpeech else { return ObservedVoiceActivityBatch() }
        return ObservedVoiceActivityBatch(
            voiceEvents: startPublication.eventsIfConfirmed(for: speech)
        )
    }

    mutating func closeEvent(
        _ speech: inout ActiveSpeech,
        reason: SpeechSegmentEndReason
    ) -> ObservedVoiceActivityBatch {
        let pauseEvents = resolvedPauseEvents(for: &speech, reason: reason)
        guard let segment = close(speech, reason: reason) else {
            return ObservedVoiceActivityBatch(pauseEvents: pauseEvents)
        }
        return ObservedVoiceActivityBatch(
            voiceEvents: [.speechEnded(segment)],
            pauseEvents: pauseEvents
        )
    }

    func resolvedPauseEvents(
        for speech: inout ActiveSpeech,
        reason: SpeechSegmentEndReason
    ) -> [CandidatePauseTraceEvent] {
        let observedAtSourceSample =
            speech.startedAtSourceSample
            + Int64(speech.samples.count)
        guard
            let event = speech.pauseResolution(
                reason: reason,
                observedAtSourceSample: observedAtSourceSample
            )
        else { return [] }
        return [event]
    }

    mutating func close(
        _ speech: ActiveSpeech,
        reason: SpeechSegmentEndReason
    ) -> SpeechSegment? {
        let segment = finalizer.finalize(speech, reason: reason)
        resetAfterClose()
        return segment
    }

    private mutating func resetAfterClose() {
        activeSpeech = nil
        startPublication.close()
        startCandidate.reset()
        preRoll.removeAll()
        decisionSmoother.reset()
    }
}
