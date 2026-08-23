import Foundation
import Testing
import TranslationQualificationSupport
@testable import TranslationHyMT2

@Suite("Hy-MT2 private negation diagnostics")
struct HyMTPrivateNegationDiagnosticTests {
    @Test(
        "replays only classified negation failures without serializing sermon text",
        .enabled(
            if: HyMTNegationDiagnosticConfiguration.isRequested(
                ProcessInfo.processInfo.environment
            ),
            "Requires an explicit private negation diagnostic opt in."
        )
    )
    func diagnosePrivateNegationFailuresWhenExplicitlyEnabled() async throws {
        guard
            let configuration = try HyMTNegationDiagnosticConfiguration.load(
                ProcessInfo.processInfo.environment
            )
        else { return }
        let inputs = try validatedInputs(configuration)
        try await execute(
            configuration,
            corpus: inputs.corpus,
            classified: inputs.classified
        )
    }

    private func execute(
        _ configuration: HyMTNegationDiagnosticConfiguration,
        corpus: TranslationQualificationCorpus,
        classified: HyMTNegationClassifiedEvidence
    ) async throws {
        let recorder = HyMTQualificationAttemptRecorder()
        let transport = HyMTNegationRecordingTransport(base: URLSessionLlamaServerTransport())
        let provider = HyMT2TranslationProvider(
            configuration: configuration.qualificationConfiguration.providerConfiguration,
            server: FoundationLlamaServerController(executableURL: configuration.helperURL),
            transport: transport,
            endpointFactory: LlamaServerEndpoint.randomLocal,
            attemptObserver: recorder
        )
        let runner = HyMTNegationDiagnosticRunner(
            provider: provider,
            transport: transport,
            recorder: recorder,
            providerConfiguration: configuration.qualificationConfiguration.providerConfiguration
        )
        try await start(provider, modelURL: configuration.modelURL)
        let result = try await replay(
            runner,
            provider: provider,
            corpus: corpus,
            classified: classified
        )
        let url = try await store(
            result,
            configuration: configuration,
            corpus: corpus,
            classified: classified,
            provider: provider
        )
        let hash = try TranslationQualificationSHA256.hash(fileAt: url)
        print("HYMT_PRIVATE_NEGATION_DIAGNOSTIC_REPORT_SHA256=\(hash)")
    }

}
