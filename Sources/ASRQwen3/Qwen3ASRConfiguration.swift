import Foundation

/// Runtime limits for the Qwen3-ASR sherpa-onnx adapter.
public struct Qwen3ASRConfiguration: Sendable {
    public let inferenceThreads: Int
    public let maximumHotwords: Int
    public let minimumRMS: Float
    public let maximumNewTokens: Int

    public init(
        inferenceThreads: Int = 2,
        maximumHotwords: Int = 48,
        minimumRMS: Float = 0.003,
        maximumNewTokens: Int = 192
    ) {
        self.inferenceThreads = max(1, inferenceThreads)
        self.maximumHotwords = max(0, maximumHotwords)
        self.minimumRMS = max(0, minimumRMS)
        self.maximumNewTokens = max(1, maximumNewTokens)
    }
}
