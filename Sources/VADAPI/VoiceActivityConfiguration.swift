/// Immutable parameters for adaptive energy-based speech segmentation.
public struct VoiceActivityConfiguration: Sendable, Equatable {
    public let requiredSampleRate: Double
    public let analysisWindow: Duration
    public let preRoll: Duration
    public let speechStart: Duration
    public let trailingSilence: Duration
    public let maximumSegment: Duration
    public let initialNoiseFloorRMS: Float
    public let minimumSpeechRMS: Float
    public let speechThresholdMultiplier: Float
    public let noiseFloorSmoothing: Float

    public init(
        requiredSampleRate: Double = 16_000,
        analysisWindow: Duration = .milliseconds(20),
        preRoll: Duration = .milliseconds(240),
        speechStart: Duration = .milliseconds(100),
        trailingSilence: Duration = .milliseconds(650),
        maximumSegment: Duration = .seconds(28),
        initialNoiseFloorRMS: Float = 0.002,
        minimumSpeechRMS: Float = 0.008,
        speechThresholdMultiplier: Float = 3,
        noiseFloorSmoothing: Float = 0.96
    ) {
        self.requiredSampleRate = requiredSampleRate
        self.analysisWindow = analysisWindow
        self.preRoll = preRoll
        self.speechStart = speechStart
        self.trailingSilence = trailingSilence
        self.maximumSegment = maximumSegment
        self.initialNoiseFloorRMS = initialNoiseFloorRMS
        self.minimumSpeechRMS = minimumSpeechRMS
        self.speechThresholdMultiplier = speechThresholdMultiplier
        self.noiseFloorSmoothing = noiseFloorSmoothing
    }

    public static let sermon = VoiceActivityConfiguration()
}
