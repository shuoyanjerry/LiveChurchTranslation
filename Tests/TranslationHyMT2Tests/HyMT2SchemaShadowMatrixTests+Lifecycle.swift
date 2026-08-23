import Foundation
import Testing
@testable import TranslationHyMT2

struct HyMT2SchemaShadowRun {
    let probe: HyMT2SchemaShadowProbeResult
    let results: [HyMT2SchemaShadowResult]
}

extension HyMT2SchemaShadowMatrixTests {
    func execute(
        _ environment: HyMT2NegationShadowQ4Environment
    ) async throws -> HyMT2SchemaShadowRun {
        let transport = HyMT2SchemaShadowTransport()
        let server = FoundationLlamaServerController(executableURL: environment.helperURL)
        let endpoint = LlamaServerEndpoint.randomLocal()
        try await launch(
            server: server,
            transport: transport,
            endpoint: endpoint,
            modelURL: environment.modelURL
        )
        do {
            let probe = try await enforceSchemaProbe(transport: transport, endpoint: endpoint)
            let results = try await runMatrix(transport: transport, endpoint: endpoint)
            await server.stop()
            #expect(!(await server.isRunning()))
            return HyMT2SchemaShadowRun(probe: probe, results: results)
        } catch {
            await server.stop()
            #expect(!(await server.isRunning()))
            throw error
        }
    }

    private func launch(
        server: FoundationLlamaServerController,
        transport: HyMT2SchemaShadowTransport,
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
