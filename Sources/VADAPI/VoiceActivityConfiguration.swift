/// Immutable parameters for adaptive energy-based speech segmentation.
public struct VoiceActivityConfiguration: Sendable, Equatable {
    public let requiredSampleRate: Double
    public let analysisWindow: Duration
    public let preRoll: Duration
    public let speechStart: Duration
    public let trailingSilence: Duration
    public let softSplitSilence: Duration
    public let softSplitAfter: Duration
    public let maximumSegment: Duration
    public let postRoll: Duration
    public let minimumVoiced: Duration
    public let decisionWindowCount: Int
    public let decisionSpeechVotes: Int
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
        softSplitSilence: Duration = .milliseconds(180),
        softSplitAfter: Duration = .seconds(14),
        maximumSegment: Duration = .seconds(27),
        postRoll: Duration = .milliseconds(180),
        minimumVoiced: Duration = .milliseconds(240),
        decisionWindowCount: Int = 5,
        decisionSpeechVotes: Int = 3,
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
        self.softSplitSilence = softSplitSilence
        self.softSplitAfter = softSplitAfter
        self.maximumSegment = maximumSegment
        self.postRoll = postRoll
        self.minimumVoiced = minimumVoiced
        self.decisionWindowCount = decisionWindowCount
        self.decisionSpeechVotes = decisionSpeechVotes
        self.initialNoiseFloorRMS = initialNoiseFloorRMS
        self.minimumSpeechRMS = minimumSpeechRMS
        self.speechThresholdMultiplier = speechThresholdMultiplier
        self.noiseFloorSmoothing = noiseFloorSmoothing
    }

    public static let sermon = VoiceActivityConfiguration()
}
