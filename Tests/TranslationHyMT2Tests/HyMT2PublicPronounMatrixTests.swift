import Foundation
import Testing
@testable import TranslationHyMT2

@Suite("Hy-MT2 public per-occurrence pronoun matrix")
struct HyMT2PublicPronounMatrixTests {
    @Test(
        "preserves each independently verified public pronoun occurrence",
        .enabled(
            if: ProcessInfo.processInfo.environment["HYMT_PUBLIC_PRONOUN_MATRIX"] == "1",
            "Requires an explicit public-only model qualification opt in."
        )
    )
    func qualifiesPublicMatrix() async throws {
        let environment = ProcessInfo.processInfo.environment
        let modelPath = try #require(environment["HYMT_MODEL_DIR"])
        let helperPath = try #require(environment["HYMT_LLAMA_SERVER"])
        let traces = HyMTQualificationPronounTraceRecorder()
        let transport = PublicMatrixRecordingTransport()
        let provider = HyMT2TranslationProvider(
            configuration: HyMT2Configuration(),
            server: FoundationLlamaServerController(
                executableURL: URL(fileURLWithPath: helperPath)
            ),
            transport: transport,
            endpointFactory: LlamaServerEndpoint.randomLocal,
            pronounTraceObserver: traces
        )
        try await provider.loadModel(at: URL(fileURLWithPath: modelPath))
        defer { Task { await provider.shutdown() } }

        for (index, fixture) in HyMT2PublicPronounFixtures.all.enumerated() {
            do {
                try await qualify(
                    fixture,
                    requestID: requestID(for: index),
                    provider: provider,
                    traces: traces,
                    transport: transport
                )
            } catch {
                let outputs = await transport.takeOutputs()
                printOutputs(outputs, fixture: fixture)
                Issue.record("Public fixture \(fixture.name) failed: \(error)")
            }
        }
    }

    private func qualify(
        _ fixture: PublicPronounFixture,
        requestID: UUID,
        provider: HyMT2TranslationProvider,
        traces: HyMTQualificationPronounTraceRecorder,
        transport: PublicMatrixRecordingTransport
    ) async throws {
        let result = try await provider.translate(try fixture.request(id: requestID))
        let outputs = await transport.takeOutputs()
        printOutputs(outputs, fixture: fixture)
        let actual = await traces.take(for: requestID).map {
            ExpectedPublicPronounTrace(
                sourceRange: $0.sourceRange,
                resolution: $0.resolution,
                realization: $0.realizationClass
            )
        }
        let expected = try fixture.expectedTraces()
        let tracesMatch = actual == expected
        let residueFree = !containsProtocolResidue(result.targetText)
        #expect(tracesMatch, "Trace mismatch in \(fixture.name)")
        #expect(residueFree, "Protocol leak in \(fixture.name)")
        let outcome = tracesMatch && residueFree ? "passed" : "failed"
        print("HYMT_PUBLIC_MATRIX_\(fixture.name)=\(outcome)")
    }

    private func printOutputs(
        _ outputs: [String],
        fixture: PublicPronounFixture
    ) {
        for (index, output) in outputs.enumerated() {
            print("HYMT_PUBLIC_MATRIX_RAW_\(fixture.name)_\(index + 1)=\(output)")
        }
    }

    private func requestID(for index: Int) throws -> UUID {
        let suffix = String(format: "%012X", index + 1)
        return try #require(
            UUID(uuidString: "C0DEC0DE-2026-4A22-8000-\(suffix)")
        )
    }

    private func containsProtocolResidue(_ target: String) -> Bool {
        if HyMT2ReservedProtocolText.containsPrefix(in: target) { return true }
        return target.range(
            of: #"P[0-9]{4}"#,
            options: .regularExpression
        ) != nil
    }
}

private actor PublicMatrixRecordingTransport: LlamaServerTransport {
    private let base = URLSessionLlamaServerTransport()
    private var outputs: [String] = []

    func checkHealth(
        at endpoint: LlamaServerEndpoint,
        timeout: TimeInterval
    ) async throws {
        try await base.checkHealth(at: endpoint, timeout: timeout)
    }

    func complete(
        _ request: LlamaCompletionRequest,
        at endpoint: LlamaServerEndpoint,
        timeout: TimeInterval
    ) async throws -> String {
        let output = try await base.complete(request, at: endpoint, timeout: timeout)
        outputs.append(output)
        return output
    }

    func takeOutputs() -> [String] {
        defer { outputs.removeAll(keepingCapacity: true) }
        return outputs
    }
}
