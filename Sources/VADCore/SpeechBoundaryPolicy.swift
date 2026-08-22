import VADAPI

extension SpeechSegmentationThresholds {
    func boundaryReason(
        for speech: ActiveSpeech,
        rawSpeech: Bool,
        smoothedSpeech: Bool
    ) -> SpeechSegmentEndReason? {
        let pause = speech.endpointPauseSampleCount
        let boundaryStart = speech.endpointPauseStartedAtSampleCount ?? speech.samples.count
        let reachedPreferredBoundary =
            speech.samples.count >= preferredMaximumSampleCount
            && pause > 0
            && !rawSpeech
            && !smoothedSpeech
        if reachedPreferredBoundary {
            return .maximumBoundary
        }
        let reachedSoftBoundary =
            boundaryStart >= softSplitAfterSampleCount && pause >= softSilenceSampleCount
        if reachedSoftBoundary {
            return .softSilence
        }
        let ordinarySilence =
            speech.voicedSampleCount < shortUtteranceSampleCount
            ? shortSilenceSampleCount
            : silenceSampleCount
        return pause >= ordinarySilence ? .trailingSilence : nil
    }
}
