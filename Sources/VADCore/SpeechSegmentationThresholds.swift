import VADAPI

struct SpeechSegmentationThresholds {
    let sampleRate: Double
    let preRollSampleCount: Int
    let speechStartSampleCount: Int
    let silenceSampleCount: Int
    let softSilenceSampleCount: Int
    let softSplitAfterSampleCount: Int
    let maximumSegmentSampleCount: Int
    let postRollSampleCount: Int
    let minimumVoicedSampleCount: Int

    init(configuration: VoiceActivityConfiguration) {
        sampleRate = configuration.requiredSampleRate
        let samples = SampleCountConverter(sampleRate: sampleRate)
        preRollSampleCount = samples.count(for: configuration.preRoll)
        speechStartSampleCount = samples.count(for: configuration.speechStart)
        silenceSampleCount = samples.count(for: configuration.trailingSilence)
        softSilenceSampleCount = samples.count(for: configuration.softSplitSilence)
        softSplitAfterSampleCount = samples.count(for: configuration.softSplitAfter)
        maximumSegmentSampleCount = samples.count(for: configuration.maximumSegment)
        postRollSampleCount = samples.countAllowingZero(for: configuration.postRoll)
        minimumVoicedSampleCount = samples.count(for: configuration.minimumVoiced)
    }
}

private struct SampleCountConverter {
    let sampleRate: Double

    func count(for duration: Duration) -> Int {
        AudioTiming.sampleCount(for: duration, sampleRate: sampleRate)
    }

    func countAllowingZero(for duration: Duration) -> Int {
        duration == .zero ? 0 : count(for: duration)
    }
}
