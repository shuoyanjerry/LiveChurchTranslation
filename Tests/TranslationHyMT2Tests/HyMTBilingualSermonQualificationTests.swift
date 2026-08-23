import Foundation
import Testing
import TranslationQualificationSupport
@testable import TranslationHyMT2

@Suite("Hy-MT2 private bilingual sermon qualification")
struct HyMTBilingualSermonQualificationTests {
    @Test(
        "replays the frozen private corpus in document order",
        .enabled(
            if: HyMTQualificationConfiguration.isRequested(ProcessInfo.processInfo.environment),
            "Requires explicit Hy-MT model, helper, corpus, and report filename."
        )
    )
    func qualifyPrivateCorpusWhenExplicitlyEnabled() async throws {
        guard
            let configuration = try HyMTQualificationConfiguration.load(
                ProcessInfo.processInfo.environment
            )
        else { return }
        let corpus = try loadCorpus(configuration)
        try HyMTQualificationGlossary.requireManifestCoverage(
            corpus.manifest.segments,
            limit: configuration.providerConfiguration.maximumGlossaryTerms
        )
        let executionGuard = try HyMTQualificationExecutionGuard.begin(
            configuration: configuration,
            corpus: corpus
        )
        let recorder = HyMTQualificationAttemptRecorder()
        let traceRecorder = HyMTQualificationPronounTraceRecorder()
        let provider = makeProvider(
            configuration,
            recorder: recorder,
            traceRecorder: traceRecorder
        )
        let execution = HyMTQualificationExecutionContext(
            recorder: recorder,
            traceRecorder: traceRecorder,
            executionGuard: executionGuard
        )
        try await execute(
            configuration: configuration,
            corpus: corpus,
            provider: provider,
            execution: execution
        )
    }

    private func loadCorpus(
        _ configuration: HyMTQualificationConfiguration
    ) throws -> TranslationQualificationCorpus {
        try TranslationQualificationCorpusLoader.load(
            manifestURL: configuration.manifestURL,
            workspaceRoot: configuration.workspaceRoot,
            expectedManifestSHA256: HyMTQualificationConfiguration.manifestSHA256,
            expectedSchemaSHA256: HyMTQualificationConfiguration.schemaSHA256
        )
    }

    private func makeProvider(
        _ configuration: HyMTQualificationConfiguration,
        recorder: HyMTQualificationAttemptRecorder,
        traceRecorder: HyMTQualificationPronounTraceRecorder
    ) -> HyMT2TranslationProvider {
        HyMT2TranslationProvider(
            configuration: configuration.providerConfiguration,
            server: FoundationLlamaServerController(executableURL: configuration.helperURL),
            transport: URLSessionLlamaServerTransport(),
            endpointFactory: LlamaServerEndpoint.randomLocal,
            attemptObserver: recorder,
            pronounTraceObserver: traceRecorder
        )
    }
}

extension HyMTBilingualSermonQualificationTests {
    private func execute(
        configuration: HyMTQualificationConfiguration,
        corpus: TranslationQualificationCorpus,
        provider: HyMT2TranslationProvider,
        execution: HyMTQualificationExecutionContext
    ) async throws {
        do {
            let maximumGlossaryTerms = configuration.providerConfiguration.maximumGlossaryTerms
            try HyMTQualificationGlossary.requireManifestCoverage(
                corpus.manifest.segments,
                limit: maximumGlossaryTerms
            )
            try await provider.loadModel(at: configuration.modelURL)
            let attempts = try await HyMTQualificationRunner(
                provider: provider,
                recorder: execution.recorder,
                pronounTraceRecorder: execution.traceRecorder,
                maximumGlossaryTerms: maximumGlossaryTerms
            ).run(corpus)
            await provider.shutdown()
            let provenance = try execution.executionGuard.finalize(configuration: configuration)
            try finalizeEvidence(
                HyMTQualificationReleaseInput(
                    configuration: configuration,
                    corpus: corpus,
                    provider: provider,
                    provenance: provenance,
                    attempts: attempts,
                    executionGuard: execution.executionGuard
                )
            )
        } catch {
            await provider.shutdown()
            throw error
        }
    }
}

private struct HyMTQualificationExecutionContext {
    let recorder: HyMTQualificationAttemptRecorder
    let traceRecorder: HyMTQualificationPronounTraceRecorder
    let executionGuard: HyMTQualificationExecutionGuard
}
