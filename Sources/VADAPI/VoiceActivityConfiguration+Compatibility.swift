extension VoiceActivityConfiguration {
    /// Creates a configuration using the original maximum-segment label.
    public init(
        requiredSampleRate: Double = 16_000,
        analysisWindow: Duration = .milliseconds(20),
        preRoll: Duration = .milliseconds(240),
        speechStart: Duration = .milliseconds(100),
        trailingSilence: Duration = .milliseconds(650),
        shortUtterance: Duration = .milliseconds(3_500),
        shortTrailingSilence: Duration = .milliseconds(950),
        softSplitSilence: Duration = .milliseconds(500),
        softSplitAfter: Duration = .seconds(9),
        maximumSegment: Duration,
        preferredBoundarySilence: Duration = .zero,
        maximumBoundaryGrace: Duration = .milliseconds(1_500),
        postRoll: Duration = .milliseconds(280),
        minimumVoiced: Duration = .milliseconds(240),
        decisionWindowCount: Int = 5,
        decisionSpeechVotes: Int = 3,
        initialNoiseFloorRMS: Float = 0.002,
        minimumSpeechRMS: Float = 0.008,
        speechThresholdMultiplier: Float = 3,
        noiseFloorSmoothing: Float = 0.96
    ) {
        self.init(
            requiredSampleRate: requiredSampleRate,
            analysisWindow: analysisWindow,
            preRoll: preRoll,
            speechStart: speechStart,
            trailingSilence: trailingSilence,
            shortUtterance: shortUtterance,
            shortTrailingSilence: shortTrailingSilence,
            softSplitSilence: softSplitSilence,
            softSplitAfter: softSplitAfter,
            preferredMaximumSegment: maximumSegment,
            preferredBoundarySilence: preferredBoundarySilence,
            maximumBoundaryGrace: maximumBoundaryGrace,
            postRoll: postRoll,
            minimumVoiced: minimumVoiced,
            decisionWindowCount: decisionWindowCount,
            decisionSpeechVotes: decisionSpeechVotes,
            initialNoiseFloorRMS: initialNoiseFloorRMS,
            minimumSpeechRMS: minimumSpeechRMS,
            speechThresholdMultiplier: speechThresholdMultiplier,
            noiseFloorSmoothing: noiseFloorSmoothing
        )
    }
}
