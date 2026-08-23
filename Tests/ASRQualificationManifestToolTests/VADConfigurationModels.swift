struct VADConfiguration: Codable, Equatable {
    let classifier: String
    let classifierMode: Int
    let classifierParameters: VADClassifierParameters
    let libfvadRevision: String
    let policy: VADPolicy
}

struct VADClassifierParameters: Codable, Equatable {
    let energyThresholdMultiplier: Double
    let initialNoiseFloorRMS: Double
    let minimumEnergyRMS: Double
    let noiseFloorRetention: Double
    let strongEnergyRMS: Double
}

struct VADPolicy: Codable, Equatable {
    let analysisWindowMs: Int
    let decisionSpeechVotes: Int
    let decisionWindowCount: Int
    let maximumBoundaryGraceMs: Int
    let minimumVoicedMs: Int
    let postRollMs: Int
    let preRollMs: Int
    let preferredBoundarySilenceMs: Int
    let preferredMaximumSegmentMs: Int
    let requiredSampleRateHz: Int
    let shortTrailingSilenceMs: Int
    let shortUtteranceMs: Int
    let softSplitAfterMs: Int
    let softSplitSilenceMs: Int
    let speechStartMs: Int
    let trailingSilenceMs: Int
}
