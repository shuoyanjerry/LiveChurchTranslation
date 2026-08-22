import Foundation

public enum SemanticEndpointError: Error, Equatable, Sendable {
    case cancelled
    case invalidSampleRate(expected: Int, actual: Int)
    case invalidChannelCount(expected: Int, actual: Int)
    case invalidSampleCount(Int)
    case nonFiniteSample(index: Int)
    case invalidThreshold(Float)
    case modelNotLoaded
    case modelFileUnavailable(String)
    case modelIntegrityMismatch(expected: String, actual: String)
    case modelLoadFailed(String)
    case inferenceFailed(String)
    case invalidModelOutput(Float)
}

extension SemanticEndpointError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cancelled:
            "Semantic endpoint analysis was cancelled."
        case .invalidSampleRate(let expected, let actual):
            "Expected \(expected) Hz mono audio, received \(actual) Hz."
        case .invalidChannelCount(let expected, let actual):
            "Expected \(expected) audio channel, received \(actual)."
        case .invalidSampleCount(let count):
            "Semantic endpoint audio must be non-empty; received \(count) samples."
        case .nonFiniteSample(let index):
            "Semantic endpoint audio contains a non-finite sample at index \(index)."
        case .invalidThreshold(let threshold):
            "Completion threshold must be finite and between 0 and 1; received \(threshold)."
        case .modelNotLoaded:
            "The semantic endpoint model is not loaded."
        case .modelFileUnavailable(let path):
            "The semantic endpoint model is unavailable at \(path)."
        case .modelIntegrityMismatch(let expected, let actual):
            "Semantic endpoint model SHA-256 mismatch: expected \(expected), received \(actual)."
        case .modelLoadFailed(let message):
            "Unable to load the semantic endpoint model: \(message)"
        case .inferenceFailed(let message):
            "Semantic endpoint inference failed: \(message)"
        case .invalidModelOutput(let value):
            "Semantic endpoint model returned an invalid probability: \(value)."
        }
    }
}
