/// Runtime policy for the isolated sherpa-onnx Fun-ASR-Nano adapter.
public struct FunASRNanoConfiguration: Sendable {
    public let inferenceThreads: Int
    public let minimumRMS: Float
    public let maximumNewTokens: Int
    public let language: String
    public let staticHotwords: String

    public init(
        inferenceThreads: Int = 2,
        minimumRMS: Float = 0.003,
        maximumNewTokens: Int = 256,
        language: String = "",
        staticHotwords: String = ""
    ) {
        self.inferenceThreads = max(1, inferenceThreads)
        self.minimumRMS = max(0, minimumRMS)
        self.maximumNewTokens = max(1, maximumNewTokens)
        self.language = language
        self.staticHotwords = staticHotwords
    }
}
