import VADAPI

struct SpeechSegmentationThresholds {
    let sampleRate: Double
    let preRollSampleCount: Int
    let speechStartSampleCount: Int
    let silenceSampleCount: Int
    let maximumSegmentSampleCount: Int

    init(configuration: VoiceActivityConfiguration) {
        sampleRate = configuration.requiredSampleRate
        preRollSampleCount = AudioTiming.sampleCount(
            for: configuration.preRoll,
            sampleRate: sampleRate
        )
        speechStartSampleCount = AudioTiming.sampleCount(
            for: configuration.speechStart,
            sampleRate: sampleRate
        )
        silenceSampleCount = AudioTiming.sampleCount(
            for: configuration.trailingSilence,
            sampleRate: sampleRate
        )
        maximumSegmentSampleCount = AudioTiming.sampleCount(
            for: configuration.maximumSegment,
            sampleRate: sampleRate
        )
    }
}
