/// Typed initialization failures from the isolated native VAD adapter.
public enum WebRTCVoiceActivityClassifierError: Error, Sendable, Equatable {
    case allocationFailed
    case invalidConfiguration(parameter: String)
    case invalidFrameLength(expected: Int, actual: Int)
    case nonFiniteSamples
    case nativeConfigurationRejected
    case nativeProcessingFailed
}
