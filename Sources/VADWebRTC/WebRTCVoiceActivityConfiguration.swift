/// Immutable settings for the WebRTC-plus-energy speech classifier.
public struct WebRTCVoiceActivityConfiguration: Sendable, Equatable {
    public let mode: WebRTCVADMode
    public let initialNoiseFloorRMS: Float
    public let minimumEnergyRMS: Float
    public let energyThresholdMultiplier: Float
    public let strongEnergyRMS: Float
    public let noiseFloorRetention: Float

    public init(
        mode: WebRTCVADMode = .aggressive,
        initialNoiseFloorRMS: Float = 0.0025,
        minimumEnergyRMS: Float = 0.006,
        energyThresholdMultiplier: Float = 3.2,
        strongEnergyRMS: Float = 0.018,
        noiseFloorRetention: Float = 0.995
    ) {
        self.mode = mode
        self.initialNoiseFloorRMS = initialNoiseFloorRMS
        self.minimumEnergyRMS = minimumEnergyRMS
        self.energyThresholdMultiplier = energyThresholdMultiplier
        self.strongEnergyRMS = strongEnergyRMS
        self.noiseFloorRetention = noiseFloorRetention
    }

    public static let sermon = WebRTCVoiceActivityConfiguration()
}
