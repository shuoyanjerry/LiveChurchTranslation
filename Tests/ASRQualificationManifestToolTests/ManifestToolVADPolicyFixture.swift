extension ManifestToolVADFixture {
    static func policy() -> [String: Any] {
        [
            "analysisWindowMs": 20,
            "decisionSpeechVotes": 3,
            "decisionWindowCount": 5,
            "maximumBoundaryGraceMs": 1_500,
            "minimumVoicedMs": 240,
            "postRollMs": 280,
            "preRollMs": 240,
            "preferredBoundarySilenceMs": 0,
            "preferredMaximumSegmentMs": 15_000,
            "requiredSampleRateHz": 16_000,
            "shortTrailingSilenceMs": 950,
            "shortUtteranceMs": 3_500,
            "softSplitAfterMs": 9_000,
            "softSplitSilenceMs": 500,
            "speechStartMs": 100,
            "trailingSilenceMs": 650,
        ]
    }
}
