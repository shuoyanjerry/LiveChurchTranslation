import Foundation
import TranslationAPI

/// Actor-isolated Hy-MT2 adapter backed by the app-bundled llama-server helper.
public actor HyMT2TranslationProvider: TranslationProvider {
    public nonisolated let identifier = "tencent.hy-mt2-1.8b.gguf.llama-cpp"

    private let configuration: HyMT2Configuration
    private let server: any LlamaServerControlling
    private let transport: any LlamaServerTransport
    private let endpointFactory: @Sendable () -> LlamaServerEndpoint
    private var endpoint: LlamaServerEndpoint?
    private var loadedModelURL: URL?

    public init(
        helperExecutableURL: URL,
        configuration: HyMT2Configuration = HyMT2Configuration()
    ) {
        self.configuration = configuration
        server = FoundationLlamaServerController(executableURL: helperExecutableURL)
        transport = URLSessionLlamaServerTransport()
        endpointFactory = LlamaServerEndpoint.randomLocal
    }

    init(
        configuration: HyMT2Configuration,
        server: any LlamaServerControlling,
        transport: any LlamaServerTransport,
        endpointFactory: @escaping @Sendable () -> LlamaServerEndpoint
    ) {
        self.configuration = configuration
        self.server = server
        self.transport = transport
        self.endpointFactory = endpointFactory
    }

    /// Loads a GGUF file or a directory containing the configured GGUF file.
    public func loadModel(at location: URL) async throws {
        let modelURL = try HyMT2ModelResolver.resolve(
            at: location,
            expectedFilename: configuration.modelFilename
        )
        if loadedModelURL == modelURL, endpoint != nil, await server.isRunning() {
            return
        }
        await shutdown()
        let endpoint = endpointFactory()
        let launch = LlamaServerLaunchRequest(
            modelURL: modelURL,
            endpoint: endpoint,
            contextSize: configuration.contextSize,
            threadCount: configuration.threadCount,
            gpuLayerCount: configuration.gpuLayerCount
        )
        do {
            try await server.launch(launch)
            try await HyMT2RuntimeReadiness(
                server: server,
                transport: transport,
                configuration: configuration
            ).wait(untilHealthy: endpoint)
            self.endpoint = endpoint
            loadedModelURL = modelURL
        } catch {
            await server.stop()
            self.endpoint = nil
            loadedModelURL = nil
            throw HyMT2ErrorNormalizer.normalized(error)
        }
    }

    public func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        let source = request.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { throw TranslationProviderError.emptySource }
        guard let endpoint, await server.isRunning() else {
            self.endpoint = nil
            loadedModelURL = nil
            throw HyMT2Error.modelNotLoaded
        }
        let terms = TranslationTermMatcher.matched(
            in: source,
            from: request.glossary,
            limit: configuration.maximumGlossaryTerms
        )
        let clock = ContinuousClock()
        let started = clock.now
        let target = try await HyMT2TranslationExecutor(
            configuration: configuration,
            transport: transport
        ).translate(
            source: source,
            targetLanguage: request.targetLanguage,
            terms: terms,
            endpoint: endpoint
        )
        return TranslationResult(
            requestID: request.id,
            sourceText: request.sourceText,
            targetText: target,
            duration: started.duration(to: clock.now)
        )
    }

    public func shutdown() async {
        await server.stop()
        endpoint = nil
        loadedModelURL = nil
    }
}
