struct SpeechStartCandidate {
    private(set) var speechSampleCount = 0
    private(set) var voicedSampleCount = 0

    mutating func observe(
        rawSpeech: Bool,
        smoothedSpeech: Bool,
        sampleCount: Int
    ) {
        voicedSampleCount = rawSpeech ? voicedSampleCount + sampleCount : 0
        guard rawSpeech, smoothedSpeech else {
            speechSampleCount = 0
            return
        }
        speechSampleCount += sampleCount
    }

    mutating func reset() {
        speechSampleCount = 0
        voicedSampleCount = 0
    }
}
