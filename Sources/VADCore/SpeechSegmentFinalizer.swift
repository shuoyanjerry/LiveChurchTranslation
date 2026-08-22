import VADAPI

struct SpeechSegmentFinalizer {
    let thresholds: SpeechSegmentationThresholds

    func finalize(
        _ speech: ActiveSpeech,
        reason: SpeechSegmentEndReason
    ) -> SpeechSegment? {
        guard speech.voicedSampleCount >= thresholds.minimumVoicedSampleCount else {
            return nil
        }
        let trailingSamplesToKeep =
            reason == .maximumDuration
            ? Int.max
            : thresholds.postRollSampleCount
        return speech.segment(
            sampleRate: thresholds.sampleRate,
            reason: reason,
            trailingSamplesToKeep: trailingSamplesToKeep
        )
    }
}
