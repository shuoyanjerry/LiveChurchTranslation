import VADAPI

extension SpeechWindowSegmenter {
    mutating func consumePendingContinuation(
        _ window: [Float],
        at timestamp: Duration,
        sourceSampleStart: Int64,
        rawSpeech: Bool,
        smoothedSpeech: Bool
    ) -> ObservedVoiceActivityBatch {
        pendingContinuation = false
        guard rawSpeech else {
            return consumeWhileIdle(
                window,
                at: timestamp,
                sourceSampleStart: sourceSampleStart,
                rawSpeech: false,
                smoothedSpeech: smoothedSpeech
            )
        }
        return beginSpeech(
            with: window,
            at: timestamp,
            sourceSampleStart: sourceSampleStart,
            voicedSampleCount: window.count,
            isConfirmedContinuation: true
        )
    }
}
