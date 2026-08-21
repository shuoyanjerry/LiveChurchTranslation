import AudioProcessingAPI
import VADAPI

/// Actor-isolated adaptive energy VAD with pre-roll and bounded segments.
public actor AdaptiveEnergyVoiceActivityDetector: VoiceActivityDetector {
    private let requiredSampleRate: Double
    private var stateMachine: VoiceActivityStateMachine

    public init(
        configuration: VoiceActivityConfiguration = .sermon
    ) throws {
        try VoiceActivityConfigurationValidator.validate(configuration)
        requiredSampleRate = configuration.requiredSampleRate
        stateMachine = VoiceActivityStateMachine(configuration: configuration)
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
