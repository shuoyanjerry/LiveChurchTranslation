/// Typed VAD failures; implementations never silently discard malformed audio.
public enum VoiceActivityError: Error, Sendable, Equatable {
    case invalidConfiguration(parameter: String)
    case unexpectedSampleRate(expected: Double, actual: Double)
    case nonFiniteSample(index: Int)
    case nonMonotonicTimestamp(previous: Duration, current: Duration)
    case discontinuousTimestamp(expected: Duration, current: Duration)
}

extension VoiceActivityError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidConfiguration(let parameter):
            "Invalid VAD configuration value: \(parameter)."
        case .unexpectedSampleRate(let expected, let actual):
            "VAD requires \(expected) Hz audio but received \(actual) Hz."
        case .nonFiniteSample(let index):
            "Processed sample at index \(index) is not finite."
        case .nonMonotonicTimestamp(let previous, let current):
            "Audio timestamp moved backwards from \(previous) to \(current)."
        case .discontinuousTimestamp(let expected, let current):
            "Audio timestamp discontinuity: expected \(expected), received \(current)."
        }
    }
}
