import Foundation
import Testing
@testable import TranslationHyMT2

@Suite("Hy-MT2 public negation-marker Q4 A/B")
struct HyMT2NegationShadowQ4MatrixTests {
    @Test(
        "compares both marker encodings on public fixtures",
        .enabled(
            if: ProcessInfo.processInfo.environment["HYMT_NEGATION_SHADOW_Q4_MATRIX"] == "1",
            "Requires an explicit public-only Q4 shadow opt in."
        )
    )
    func qualifiesPublicMatrix() async throws {
        let environment = try HyMT2NegationShadowQ4Environment.load(
            ProcessInfo.processInfo.environment
        )
        let transport = HyMT2NegationShadowQ4Transport()
        let server = FoundationLlamaServerController(executableURL: environment.helperURL)
        let endpoint = LlamaServerEndpoint.randomLocal()
        try await launch(
            server: server,
            transport: transport,
            endpoint: endpoint,
            modelURL: environment.modelURL
        )
        let results: [HyMT2NegationShadowQ4Result]
        do {
            results = try await runMatrix(transport: transport, endpoint: endpoint)
        } catch {
            await server.stop()
            throw error
        }
        await server.stop()
        let stillRunning = await server.isRunning()
        #expect(!stillRunning)

        let ordered = results.sorted {
            ($0.encoding, $0.fixtureID) < ($1.encoding, $1.fixtureID)
        }
        let report = HyMT2NegationShadowQ4Report(
            environment: environment,
            results: ordered
        )
        try HyMT2NegationShadowQ4ReportWriter.write(report, to: environment.reportURL)
        recordFailures(ordered)
    }

    private func launch(
        server: FoundationLlamaServerController,
        transport: HyMT2NegationShadowQ4Transport,
        endpoint: LlamaServerEndpoint,
        modelURL: URL
    ) async throws {
        let settings = HyMT2NegationShadowQ4Settings.self
        try await server.launch(
            LlamaServerLaunchRequest(
                modelURL: modelURL,
                endpoint: endpoint,
                contextSize: settings.contextSize,
                threadCount: settings.threadCount,
                gpuLayerCount: settings.gpuLayerCount
            )
        )
        do {
            try await HyMT2RuntimeReadiness(
                server: server,
                transport: transport,
                configuration: settings.runtimeConfiguration
            ).wait(untilHealthy: endpoint)
        } catch {
            await server.stop()
            throw error
        }
    }

}
