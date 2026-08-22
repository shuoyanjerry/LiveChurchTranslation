import Foundation
import SemanticEndpointAPI

/// Actor-isolated Pipecat Smart Turn v3.2 CPU adapter.
public actor SmartTurnSemanticEndpointAnalyzer: SemanticEndpointAnalyzing {
    public nonisolated static var onnxRuntimeVersion: String {
        SmartTurnOnnxSession.runtimeVersion
    }

    private let configuration: SmartTurnConfiguration
    private let featureExtractor: SmartTurnWhisperFeatureExtractor
    private var session: SmartTurnOnnxSession?

    public init(configuration: SmartTurnConfiguration = .default) {
        self.configuration = configuration
        featureExtractor = SmartTurnWhisperFeatureExtractor()
    }

    public func loadModel(at location: URL) async throws {
        do {
            try Task.checkCancellation()
            try SmartTurnModelIntegrity.validate(location, identity: .version3Point2CPU)
            try Task.checkCancellation()
            let loadedSession = try SmartTurnOnnxSession(modelLocation: location)
            try Task.checkCancellation()
            session = loadedSession
        } catch is CancellationError {
            throw SemanticEndpointError.cancelled
        }
    }

    public func analyze(_ audio: SemanticTurnAudio) async throws -> SemanticEndpointResult {
        do {
            try Task.checkCancellation()
            try Self.validate(audio)
            guard let session else {
                throw SemanticEndpointError.modelNotLoaded
            }
            var features = try featureExtractor.extract(audio.samples)
            try Task.checkCancellation()
            let probability = try session.predict(features: &features)
            try Task.checkCancellation()
            guard probability.isFinite, (0...1).contains(probability) else {
                throw SemanticEndpointError.invalidModelOutput(probability)
            }
            let decision: SemanticEndpointDecision =
                probability > configuration.completionThreshold ? .complete : .incomplete
            return SemanticEndpointResult(
                probability: probability,
                decision: decision,
                completionThreshold: configuration.completionThreshold
            )
        } catch is CancellationError {
            throw SemanticEndpointError.cancelled
        }
    }

    public func shutdown() async {
        session = nil
    }

    private static func validate(_ audio: SemanticTurnAudio) throws {
        guard audio.sampleRate == 16_000 else {
            throw SemanticEndpointError.invalidSampleRate(
                expected: 16_000,
                actual: audio.sampleRate
            )
        }
        guard audio.channelCount == 1 else {
            throw SemanticEndpointError.invalidChannelCount(expected: 1, actual: audio.channelCount)
        }
        guard !audio.samples.isEmpty else {
            throw SemanticEndpointError.invalidSampleCount(audio.samples.count)
        }
        if let index = audio.samples.firstIndex(where: { !$0.isFinite }) {
            throw SemanticEndpointError.nonFiniteSample(index: index)
        }
    }
}
