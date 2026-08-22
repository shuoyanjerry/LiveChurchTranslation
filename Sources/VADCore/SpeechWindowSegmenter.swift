import VADAPI

struct SpeechWindowSegmenter {
    private let thresholds: SpeechSegmentationThresholds
    private let finalizer: SpeechSegmentFinalizer
    private var classifier: any VoiceActivityClassifying
    private var decisionSmoother: SpeechDecisionSmoother
    private var preRoll: RollingAudioBuffer
    private var startCandidate = SpeechStartCandidate()
    private var activeSpeech: ActiveSpeech?
    private var startPublication: SpeechStartPublication
    private var pendingContinuation = false

    init(
        configuration: VoiceActivityConfiguration,
        classifier: any VoiceActivityClassifying
    ) {
        let thresholds = SpeechSegmentationThresholds(configuration: configuration)
        self.thresholds = thresholds
        finalizer = SpeechSegmentFinalizer(thresholds: thresholds)
        self.classifier = classifier
        decisionSmoother = SpeechDecisionSmoother(configuration: configuration)
        startPublication = SpeechStartPublication(
            minimumVoicedSampleCount: thresholds.minimumVoicedSampleCount
        )
        preRoll = RollingAudioBuffer(
            capacity: thresholds.preRollSampleCount,
            sampleRate: thresholds.sampleRate
        )
    }

    mutating func consume(
        _ window: [Float],
        at timestamp: Duration
    ) -> [VoiceActivityEvent] {
        let rawSpeech = classifier.isSpeech(window, whileSpeaking: activeSpeech != nil)
        let smoothedSpeech = decisionSmoother.append(rawSpeech)
        if activeSpeech != nil {
            return consumeWhileSpeaking(
                window,
                rawSpeech: rawSpeech,
                smoothedSpeech: smoothedSpeech
            )
        }
        if pendingContinuation {
            pendingContinuation = false
            guard rawSpeech else {
                return consumeWhileIdle(
                    window,
                    at: timestamp,
                    rawSpeech: false,
                    smoothedSpeech: smoothedSpeech
                )
            }
            return beginSpeech(
                with: window,
                at: timestamp,
                voicedSampleCount: window.count
            )
        }
        return consumeWhileIdle(
            window,
            at: timestamp,
            rawSpeech: rawSpeech,
            smoothedSpeech: smoothedSpeech
        )
    }

    mutating func flush() -> [VoiceActivityEvent] {
        guard let speech = activeSpeech, !speech.samples.isEmpty else { return [] }
        var events = startPublication.eventsIfConfirmed(for: speech)
        guard let segment = close(speech, reason: .endOfStream) else { return events }
        events.append(.speechEnded(segment))
        return events
    }

    mutating func reset(resetSequence: Bool) {
        startCandidate.reset()
        activeSpeech = nil
        startPublication.reset(resetSequence: resetSequence)
        pendingContinuation = false
        preRoll.removeAll()
        classifier.reset()
        decisionSmoother.reset()
    }
}

extension SpeechWindowSegmenter {
    private mutating func consumeWhileIdle(
        _ window: [Float],
        at timestamp: Duration,
        rawSpeech: Bool,
        smoothedSpeech: Bool
    ) -> [VoiceActivityEvent] {
        preRoll.append(window, at: timestamp)
        startCandidate.observe(
            rawSpeech: rawSpeech,
            smoothedSpeech: smoothedSpeech,
            sampleCount: window.count
        )
        guard startCandidate.speechSampleCount >= thresholds.speechStartSampleCount else {
            return []
        }
        let samples = preRoll.samples
        let start = preRoll.startedAt ?? timestamp
        return beginSpeech(
            with: samples,
            at: start,
            voicedSampleCount: min(startCandidate.voicedSampleCount, samples.count)
        )
    }

    private mutating func consumeWhileSpeaking(
        _ window: [Float],
        rawSpeech: Bool,
        smoothedSpeech: Bool
    ) -> [VoiceActivityEvent] {
        activeSpeech?.append(window, rawSpeech: rawSpeech)
        guard let speech = activeSpeech else { return [] }
        var events = startPublication.eventsIfConfirmed(for: speech)
        if let reason = thresholds.boundaryReason(
            for: speech,
            rawSpeech: rawSpeech,
            smoothedSpeech: smoothedSpeech
        ) {
            events += closeEvent(speech, reason: reason)
            return events
        }
        if speech.samples.count >= thresholds.hardMaximumSampleCount {
            pendingContinuation = rawSpeech
            events += closeEvent(speech, reason: .maximumDuration)
            return events
        }
        return events
    }

    private mutating func beginSpeech(
        with samples: [Float],
        at timestamp: Duration,
        voicedSampleCount: Int
    ) -> [VoiceActivityEvent] {
        let sequence = startPublication.nextSequenceNumber
        activeSpeech = ActiveSpeech(
            sequenceNumber: sequence,
            samples: samples,
            startedAt: timestamp,
            voicedSampleCount: voicedSampleCount
        )
        startCandidate.reset()
        preRoll.removeAll()
        guard let speech = activeSpeech else { return [] }
        return startPublication.eventsIfConfirmed(for: speech)
    }

    private mutating func closeEvent(
        _ speech: ActiveSpeech,
        reason: SpeechSegmentEndReason
    ) -> [VoiceActivityEvent] {
        guard let segment = close(speech, reason: reason) else { return [] }
        return [.speechEnded(segment)]
    }

    private mutating func close(
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
