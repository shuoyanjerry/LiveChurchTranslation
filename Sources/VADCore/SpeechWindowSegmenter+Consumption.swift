import VADAPI

extension SpeechWindowSegmenter {
    mutating func consumeWhileIdle(
        _ window: [Float],
        at timestamp: Duration,
        sourceSampleStart: Int64,
        rawSpeech: Bool,
        smoothedSpeech: Bool
    ) -> ObservedVoiceActivityBatch {
        preRoll.append(
            window,
            at: timestamp,
            sourceSampleStart: sourceSampleStart
        )
        startCandidate.observe(
            rawSpeech: rawSpeech,
            smoothedSpeech: smoothedSpeech,
            sampleCount: window.count
        )
        guard startCandidate.speechSampleCount >= thresholds.speechStartSampleCount else {
            return ObservedVoiceActivityBatch()
        }
        let samples = preRoll.samples
        let start = preRoll.startedAt ?? timestamp
        let startSourceSample = preRoll.startedAtSourceSample ?? sourceSampleStart
        return beginSpeech(
            with: samples,
            at: start,
            sourceSampleStart: startSourceSample,
            voicedSampleCount: min(startCandidate.voicedSampleCount, samples.count)
        )
    }

    mutating func consumeWhileSpeaking(
        _ window: [Float],
        sourceSampleStart: Int64,
        rawSpeech: Bool,
        smoothedSpeech: Bool
    ) -> ObservedVoiceActivityBatch {
        let pauseEvents = appendPauseEvidence(
            window,
            sourceSampleStart: sourceSampleStart,
            rawSpeech: rawSpeech
        )
        guard var speech = activeSpeech else { return ObservedVoiceActivityBatch() }
        var voiceEvents = startPublication.eventsIfConfirmed(for: speech)
        if let reason = thresholds.boundaryReason(
            for: speech,
            rawSpeech: rawSpeech,
            smoothedSpeech: smoothedSpeech
        ) {
            let closed = closeEvent(&speech, reason: reason)
            return ObservedVoiceActivityBatch(
                voiceEvents: voiceEvents + closed.voiceEvents,
                pauseEvents: pauseEvents + closed.pauseEvents
            )
        }
        if speech.samples.count >= thresholds.hardMaximumSampleCount {
            let closed = closeEvent(&speech, reason: .maximumDuration)
            pendingContinuation = rawSpeech && !closed.voiceEvents.isEmpty
            voiceEvents += closed.voiceEvents
            return ObservedVoiceActivityBatch(
                voiceEvents: voiceEvents,
                pauseEvents: pauseEvents + closed.pauseEvents
            )
        }
        return ObservedVoiceActivityBatch(
            voiceEvents: voiceEvents,
            pauseEvents: pauseEvents
        )
    }

    private mutating func appendPauseEvidence(
        _ window: [Float],
        sourceSampleStart: Int64,
        rawSpeech: Bool
    ) -> [CandidatePauseTraceEvent] {
        let traceEligible =
            startPublication.hasPublishedSpeech
            || activeSpeech?.isConfirmedContinuation == true
        return activeSpeech?.append(
            window,
            sourceSampleStart: sourceSampleStart,
            rawSpeech: rawSpeech,
            traceEligible: traceEligible
        ) ?? []
    }
}
