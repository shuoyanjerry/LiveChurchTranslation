struct EndpointPauseTracker {
    private(set) var silenceSampleCount = 0
    private(set) var startedAtSampleCount: Int?
    private var consecutiveSpeechFrameCount = 0

    mutating func observe(
        rawSpeech: Bool,
        sampleCount: Int,
        precedingSampleCount: Int
    ) {
        guard rawSpeech else {
            if startedAtSampleCount == nil {
                startedAtSampleCount = precedingSampleCount
            }
            consecutiveSpeechFrameCount = 0
            silenceSampleCount += sampleCount
            return
        }
        guard silenceSampleCount > 0 else { return }
        consecutiveSpeechFrameCount += 1
        if consecutiveSpeechFrameCount >= 2 {
            reset()
        }
    }

    mutating func reset() {
        silenceSampleCount = 0
        startedAtSampleCount = nil
        consecutiveSpeechFrameCount = 0
    }
}
