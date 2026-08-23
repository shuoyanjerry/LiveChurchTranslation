import VADAPI

enum VoiceActivityConfigurationValidator {
    static func validate(_ value: VoiceActivityConfiguration) throws {
        try require(value.requiredSampleRate.isFinite && value.requiredSampleRate > 0, "requiredSampleRate")
        try require(value.analysisWindow > .zero, "analysisWindow")
        try require(value.preRoll >= value.speechStart, "preRoll")
        try require(value.speechStart > .zero, "speechStart")
        try require(value.trailingSilence > .zero, "trailingSilence")
        try require(value.shortUtterance >= value.minimumVoiced, "shortUtterance")
        try require(
            value.shortTrailingSilence >= value.trailingSilence,
            "shortTrailingSilence"
        )
        try require(value.softSplitSilence > .zero, "softSplitSilence")
        try require(value.softSplitAfter > value.preRoll, "softSplitAfter")
        try require(
            value.preferredMaximumSegment > value.preRoll,
            "preferredMaximumSegment"
        )
        try require(value.preferredBoundarySilence >= .zero, "preferredBoundarySilence")
        try require(value.maximumBoundaryGrace >= .zero, "maximumBoundaryGrace")
        try require(value.postRoll >= .zero, "postRoll")
        try require(value.minimumVoiced > .zero, "minimumVoiced")
        try require(value.decisionWindowCount > 0, "decisionWindowCount")
        try require(value.decisionSpeechVotes > 0, "decisionSpeechVotes")
        try require(
            value.decisionSpeechVotes <= value.decisionWindowCount,
            "decisionSpeechVotes"
        )
        try require(
            value.initialNoiseFloorRMS.isFinite && value.initialNoiseFloorRMS >= 0, "initialNoiseFloorRMS")
        try require(value.minimumSpeechRMS.isFinite && value.minimumSpeechRMS > 0, "minimumSpeechRMS")
        try require(
            value.speechThresholdMultiplier.isFinite && value.speechThresholdMultiplier > 1,
            "speechThresholdMultiplier")
        try require(value.noiseFloorSmoothing.isFinite, "noiseFloorSmoothing")
        try require((0..<1).contains(value.noiseFloorSmoothing), "noiseFloorSmoothing")
    }

    private static func require(_ condition: Bool, _ parameter: String) throws {
        guard condition else {
            throw VoiceActivityError.invalidConfiguration(parameter: parameter)
        }
    }
}
