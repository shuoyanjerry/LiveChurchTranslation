import Foundation

/// Explicit validation and durability failures at the handoff boundary.
public enum UtteranceRecoveryError: Error, Sendable, Equatable {
    case emptySamples
    case sampleCountExceeded(actual: Int, maximum: Int)
    case audioFileSizeExceeded(actual: Int, maximum: Int)
    case invalidSampleRate(Double)
    case nonFiniteSample(index: Int)
    case invalidTiming
    case invalidConfiguration(String)
    case rootEntryCountExceeded(maximum: Int)
    case sessionCountExceeded(maximum: Int)
    case sessionEntryCountExceeded(sessionID: UUID, maximum: Int)
    case totalRecoveryCountExceeded(maximum: Int)
    case duplicate(PendingUtteranceID)
    case recordNotFound(PendingUtteranceID)
    case fileSystem(operation: String, reason: String)
}
