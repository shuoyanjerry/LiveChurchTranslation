import AudioProcessingAPI
import VADAPI

/// Actor-isolated sermon segmenter with a replaceable speech classifier.
public actor CalibratedVoiceActivityDetector: VoiceActivityDetector {
    private let requiredSampleRate: Double
    private var stateMachine: VoiceActivityStateMachine

    public init(
        configuration: VoiceActivityConfiguration = .sermon
    ) throws {
        try self.init(
            classifier: AdaptiveEnergyClassifier(configuration: configuration),
            configuration: configuration
        )
    }

    public init(
        classifier: any VoiceActivityClassifying,
        configuration: VoiceActivityConfiguration = .sermon
    ) throws {
        try VoiceActivityConfigurationValidator.validate(configuration)
        requiredSampleRate = configuration.requiredSampleRate
        stateMachine = VoiceActivityStateMachine(
            configuration: configuration,
            classifier: classifier
        )
    }

    public func process(
        _ frame: ProcessedAudioFrame
    ) async throws -> [VoiceActivityEvent] {
        try ProcessedAudioFrameValidator.validate(
            frame,
            requiredSampleRate: requiredSampleRate,
            previousTimestamp: stateMachine.lastFrameTimestamp
        )
        return stateMachine.process(frame)
    }

    public func flush() async -> [VoiceActivityEvent] {
        stateMachine.flush()
    }

    public func reset() async {
        stateMachine.reset()
    }
}

/// Compatibility spelling for the built-in adaptive-energy fallback.
public typealias AdaptiveEnergyVoiceActivityDetector = CalibratedVoiceActivityDetector
