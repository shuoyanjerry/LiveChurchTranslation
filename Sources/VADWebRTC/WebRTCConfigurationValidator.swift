enum WebRTCConfigurationValidator {
    static func validate(
        _ value: WebRTCVoiceActivityConfiguration
    ) throws {
        try require(
            value.initialNoiseFloorRMS.isFinite && value.initialNoiseFloorRMS >= 0,
            "initialNoiseFloorRMS"
        )
        try require(
            value.minimumEnergyRMS.isFinite && value.minimumEnergyRMS > 0,
            "minimumEnergyRMS"
        )
        try require(
            value.energyThresholdMultiplier.isFinite && value.energyThresholdMultiplier > 1,
            "energyThresholdMultiplier"
        )
        try require(
            value.strongEnergyRMS.isFinite
                && value.strongEnergyRMS >= value.minimumEnergyRMS,
            "strongEnergyRMS"
        )
        try require(
            value.noiseFloorRetention.isFinite
                && (0..<1).contains(value.noiseFloorRetention),
            "noiseFloorRetention"
        )
    }

    private static func require(
        _ condition: Bool,
        _ parameter: String
    ) throws {
        guard condition else {
            throw WebRTCVoiceActivityClassifierError.invalidConfiguration(
                parameter: parameter
            )
        }
    }
}
