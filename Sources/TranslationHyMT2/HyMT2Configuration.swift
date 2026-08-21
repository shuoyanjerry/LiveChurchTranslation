import Foundation

/// Immutable runtime tuning for the bundled Hy-MT2 llama.cpp adapter.
public struct HyMT2Configuration: Sendable {
    public let modelFilename: String
    public let startupTimeout: Duration
    public let healthPollInterval: Duration
    public let requestTimeout: TimeInterval
    public let contextSize: Int
    public let maximumOutputTokens: Int
    public let threadCount: Int
    public let gpuLayerCount: Int
    public let maximumGlossaryTerms: Int

    public init(
        modelFilename: String = "Hy-MT2-1.8B-Q4_K_M.gguf",
        startupTimeout: Duration = .seconds(45),
        healthPollInterval: Duration = .milliseconds(150),
        requestTimeout: TimeInterval = 30,
        contextSize: Int = 4_096,
        maximumOutputTokens: Int = 768,
        threadCount: Int = 4,
        gpuLayerCount: Int = 99,
        maximumGlossaryTerms: Int = 64
    ) {
        self.modelFilename = modelFilename
        self.startupTimeout = startupTimeout
        self.healthPollInterval = healthPollInterval
        self.requestTimeout = requestTimeout
        self.contextSize = contextSize
        self.maximumOutputTokens = maximumOutputTokens
        self.threadCount = threadCount
        self.gpuLayerCount = gpuLayerCount
        self.maximumGlossaryTerms = maximumGlossaryTerms
    }
}
