import Foundation

/// Replaceable semantic end-of-turn boundary. Implementations own their model runtime.
public protocol SemanticEndpointAnalyzing: Sendable {
    func loadModel(at location: URL) async throws
    func analyze(_ audio: SemanticTurnAudio) async throws -> SemanticEndpointResult
    func shutdown() async
}

/// Immutable mono turn audio. Interleaved multi-channel buffers must be mixed down by the caller.
public struct SemanticTurnAudio: Equatable, Sendable {
    public let samples: [Float]
    public let sampleRate: Int
    public let channelCount: Int

    public init(
        samples: [Float],
        sampleRate: Int = 16_000,
        channelCount: Int = 1
    ) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

public enum SemanticEndpointDecision: Equatable, Sendable {
    case incomplete
    case complete
}

/// Model probability plus the adapter policy that interpreted it.
public struct SemanticEndpointResult: Equatable, Sendable {
    public let probability: Float
    public let decision: SemanticEndpointDecision
    public let completionThreshold: Float

    public init(
        probability: Float,
        decision: SemanticEndpointDecision,
        completionThreshold: Float
    ) {
        self.probability = probability
        self.decision = decision
        self.completionThreshold = completionThreshold
    }
}
