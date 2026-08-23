import VADAPI

struct SpeechWindowSegmenter {
    let thresholds: SpeechSegmentationThresholds
    let finalizer: SpeechSegmentFinalizer
    private var classifier: any VoiceActivityClassifying
    var decisionSmoother: SpeechDecisionSmoother
    var preRoll: RollingAudioBuffer
    var startCandidate = SpeechStartCandidate()
    var activeSpeech: ActiveSpeech?
    var startPublication: SpeechStartPublication
    var pendingContinuation = false

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
        at timestamp: Duration,
        sourceSampleStart: Int64,
        validSampleCount: Int? = nil
    ) -> ObservedVoiceActivityBatch {
        let retainedCount = validSampleCount ?? window.count
        precondition((0...window.count).contains(retainedCount))
        let retainedWindow = retainedSamples(from: window, count: retainedCount)
        let rawSpeech = classifier.isSpeech(window, whileSpeaking: activeSpeech != nil)
        let smoothedSpeech = decisionSmoother.append(rawSpeech)
        if activeSpeech != nil {
            return consumeWhileSpeaking(
                retainedWindow,
                sourceSampleStart: sourceSampleStart,
                rawSpeech: rawSpeech,
                smoothedSpeech: smoothedSpeech
            )
        }
        if pendingContinuation {
            return consumePendingContinuation(
                retainedWindow,
                at: timestamp,
                sourceSampleStart: sourceSampleStart,
                rawSpeech: rawSpeech,
                smoothedSpeech: smoothedSpeech
            )
        }
        return consumeWhileIdle(
            retainedWindow,
            at: timestamp,
            sourceSampleStart: sourceSampleStart,
            rawSpeech: rawSpeech,
            smoothedSpeech: smoothedSpeech
        )
    }

    mutating func flush() -> ObservedVoiceActivityBatch {
        guard var speech = activeSpeech, !speech.samples.isEmpty else {
            return ObservedVoiceActivityBatch()
        }
        var events = startPublication.eventsIfConfirmed(for: speech)
        let pauseEvents = resolvedPauseEvents(for: &speech, reason: .endOfStream)
        guard let segment = close(speech, reason: .endOfStream) else {
            return ObservedVoiceActivityBatch(
                voiceEvents: events,
                pauseEvents: pauseEvents
            )
        }
        events.append(.speechEnded(segment))
        return ObservedVoiceActivityBatch(
            voiceEvents: events,
            pauseEvents: pauseEvents
        )
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

    private func retainedSamples(from window: [Float], count: Int) -> [Float] {
        count == window.count ? window : Array(window.prefix(count))
    }
}
