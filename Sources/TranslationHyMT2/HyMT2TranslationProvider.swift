import Foundation
import ModelRuntimeAPI
import TranslationAPI

/// Actor-isolated Hy-MT2 adapter backed by the app-bundled llama-server helper.
public actor HyMT2TranslationProvider: TranslationProvider, ModelRuntimeHealthChecking {
    public nonisolated let identifier = "tencent.hy-mt2-1.8b.gguf.llama-cpp"

    private let configuration: HyMT2Configuration
    private let server: any LlamaServerControlling
    private let transport: any LlamaServerTransport
    private let endpointFactory: @Sendable () -> LlamaServerEndpoint
    private let attemptObserver: any HyMT2AttemptObserving
    private let pronounTraceObserver: any HyMT2PronounTraceObserving
    private let pronounDiagnosticObserver: any HyMT2PronounDiagnosticObserving
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
        attemptObserver = HyMT2NoOpAttemptObserver()
        pronounTraceObserver = HyMT2NoOpPronounTraceObserver()
        pronounDiagnosticObserver = HyMT2NoOpPronounDiagnosticObserver()
    }

    init(
        configuration: HyMT2Configuration,
        server: any LlamaServerControlling,
        transport: any LlamaServerTransport,
        endpointFactory: @escaping @Sendable () -> LlamaServerEndpoint,
        attemptObserver: any HyMT2AttemptObserving = HyMT2NoOpAttemptObserver(),
        pronounTraceObserver: any HyMT2PronounTraceObserving = HyMT2NoOpPronounTraceObserver(),
        pronounDiagnosticObserver: any HyMT2PronounDiagnosticObserving =
            HyMT2NoOpPronounDiagnosticObserver()
    ) {
        self.configuration = configuration
        self.server = server
        self.transport = transport
        self.endpointFactory = endpointFactory
        self.attemptObserver = attemptObserver
        self.pronounTraceObserver = pronounTraceObserver
        self.pronounDiagnosticObserver = pronounDiagnosticObserver
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
        let trimmedSource = request.sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else { throw TranslationProviderError.emptySource }
        guard let endpoint, await server.isRunning() else {
            self.endpoint = nil
            loadedModelURL = nil
            throw HyMT2Error.modelNotLoaded
        }
        let input = HyMT2TranslationInputFactory.make(
            request,
            trimmedSource: trimmedSource,
            maximumGlossaryTerms: configuration.maximumGlossaryTerms
        )
        let clock = ContinuousClock()
        let started = clock.now
        let target = try await HyMT2TranslationExecutor(
            configuration: configuration,
            transport: transport,
            attemptObserver: attemptObserver,
            pronounTraceObserver: pronounTraceObserver,
            pronounDiagnosticObserver: pronounDiagnosticObserver
        ).translate(
            input,
            endpoint: endpoint,
            requestID: request.id
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

    public func isModelRuntimeReady() async -> Bool {
        guard endpoint != nil, loadedModelURL != nil else { return false }
        return await server.isRunning()
    }
}
