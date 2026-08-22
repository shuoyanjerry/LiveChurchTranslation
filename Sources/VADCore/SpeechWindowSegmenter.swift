import VADAPI

struct SpeechWindowSegmenter {
    private let thresholds: SpeechSegmentationThresholds
    private var classifier: AdaptiveEnergyClassifier
    private var decisionSmoother: SpeechDecisionSmoother
    private var preRoll: RollingAudioBuffer
    private var candidateSpeechSampleCount = 0
    private var activeSpeech: ActiveSpeech?
    private var pendingContinuation = false
    private var nextSequenceNumber: UInt64 = 1

    init(configuration: VoiceActivityConfiguration) {
        let thresholds = SpeechSegmentationThresholds(configuration: configuration)
        self.thresholds = thresholds
        classifier = AdaptiveEnergyClassifier(configuration: configuration)
        decisionSmoother = SpeechDecisionSmoother(configuration: configuration)
        preRoll = RollingAudioBuffer(
            capacity: thresholds.preRollSampleCount,
            sampleRate: thresholds.sampleRate
        )
    }

    mutating func consume(
        _ window: [Float],
        at timestamp: Duration
    ) -> [VoiceActivityEvent] {
        let rawSpeech = classifier.isSpeech(
            window,
            whileSpeaking: activeSpeech != nil
        )
        let isSpeech = decisionSmoother.append(rawSpeech)
        if activeSpeech != nil {
            return consumeWhileSpeaking(window, isSpeech: isSpeech)
        }
        if pendingContinuation {
            pendingContinuation = false
            guard isSpeech else {
                return consumeWhileIdle(window, at: timestamp, isSpeech: false)
            }
            return [startSpeech(with: window, at: timestamp)]
        }
        return consumeWhileIdle(window, at: timestamp, isSpeech: isSpeech)
    }

    mutating func flush() -> SpeechSegment? {
        guard let speech = activeSpeech, !speech.samples.isEmpty else { return nil }
        return close(speech, reason: .endOfStream)
    }

    mutating func reset(resetSequence: Bool) {
        candidateSpeechSampleCount = 0
        activeSpeech = nil
        pendingContinuation = false
        preRoll.removeAll()
        classifier.reset()
        decisionSmoother.reset()
        if resetSequence {
            nextSequenceNumber = 1
        }
    }
}

extension SpeechWindowSegmenter {
    private mutating func consumeWhileIdle(
        _ window: [Float],
        at timestamp: Duration,
        isSpeech: Bool
    ) -> [VoiceActivityEvent] {
        preRoll.append(window, at: timestamp)
        candidateSpeechSampleCount =
            isSpeech
            ? candidateSpeechSampleCount + window.count
            : 0
        guard candidateSpeechSampleCount >= thresholds.speechStartSampleCount else {
            return []
        }
        let samples = preRoll.samples
        let start = preRoll.startedAt ?? timestamp
        return [startSpeech(with: samples, at: start)]
    }

    private mutating func consumeWhileSpeaking(
        _ window: [Float],
        isSpeech: Bool
    ) -> [VoiceActivityEvent] {
        activeSpeech?.append(window, isSpeech: isSpeech)
        guard let speech = activeSpeech else { return [] }
        if speech.samples.count >= thresholds.maximumSegmentSampleCount {
            pendingContinuation = isSpeech
            return closeEvent(speech, reason: .maximumDuration)
        }
        let canSoftSplit =
            speech.samples.count >= thresholds.softSplitAfterSampleCount
            && speech.trailingSilenceSampleCount >= thresholds.softSilenceSampleCount
        if canSoftSplit {
            return closeEvent(speech, reason: .softSilence)
        }
        if speech.trailingSilenceSampleCount >= thresholds.silenceSampleCount {
            return closeEvent(speech, reason: .trailingSilence)
        }
        return []
    }

    private mutating func startSpeech(
        with samples: [Float],
        at timestamp: Duration
    ) -> VoiceActivityEvent {
        let sequence = nextSequenceNumber
        nextSequenceNumber += 1
        activeSpeech = ActiveSpeech(
            sequenceNumber: sequence,
            samples: samples,
            startedAt: timestamp,
            voicedSampleCount: candidateSpeechSampleCount
        )
        candidateSpeechSampleCount = 0
        preRoll.removeAll()
        return .speechStarted(sequenceNumber: sequence, at: timestamp)
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
        let keepTrailing = reason == .maximumDuration ? Int.max : thresholds.postRollSampleCount
        let segment = speech.segment(
            sampleRate: thresholds.sampleRate,
            reason: reason,
            trailingSamplesToKeep: keepTrailing
        )
        activeSpeech = nil
        candidateSpeechSampleCount = 0
        preRoll.removeAll()
        if reason != .maximumDuration {
            decisionSmoother.reset()
        }
        guard speech.voicedSampleCount >= thresholds.minimumVoicedSampleCount else {
            return nil
        }
        return segment
    }
}
