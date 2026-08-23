@testable import TranslationHyMT2

@MainActor
func makeTranslationHarness(
    responses: [Result<String, HyMT2Error>],
    attemptObserver: any HyMT2AttemptObserving = HyMT2NoOpAttemptObserver(),
    pronounTraceObserver: any HyMT2PronounTraceObserving = HyMT2NoOpPronounTraceObserver(),
    pronounDiagnosticObserver: any HyMT2PronounDiagnosticObserving =
        HyMT2NoOpPronounDiagnosticObserver()
) async throws -> TranslationHarness {
    let model = try TemporaryGGUF()
    let server = FakeLlamaServerController()
    let transport = FakeLlamaServerTransport(responses: responses)
    let provider = HyMT2TranslationProvider(
        configuration: HyMT2TestSupport.configuration(),
        server: server,
        transport: transport,
        endpointFactory: { HyMT2TestSupport.endpoint },
        attemptObserver: attemptObserver,
        pronounTraceObserver: pronounTraceObserver,
        pronounDiagnosticObserver: pronounDiagnosticObserver
    )
    try await provider.loadModel(at: model.fileURL)
    return TranslationHarness(
        model: model,
        provider: provider,
        transport: transport
    )
}

struct TranslationHarness {
    let model: TemporaryGGUF
    let provider: HyMT2TranslationProvider
    let transport: FakeLlamaServerTransport
}
