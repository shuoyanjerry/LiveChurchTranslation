import Foundation
import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite("Hy-MT2 public theological negation matrix")
struct HyMT2PublicNegationMatrixTests {
    @Test(
        "preserves explicit Mandarin negation without requiring one English surface form",
        .enabled(
            if: ProcessInfo.processInfo.environment["HYMT_PUBLIC_NEGATION_MATRIX"] == "1",
            "Requires an explicit public-only model qualification opt in."
        )
    )
    func qualifiesPublicMatrix() async throws {
        let environment = ProcessInfo.processInfo.environment
        let modelPath = try #require(environment["HYMT_MODEL_DIR"])
        let helperPath = try #require(environment["HYMT_LLAMA_SERVER"])
        let transport = PublicNegationRecordingTransport()
        let provider = HyMT2TranslationProvider(
            configuration: HyMT2Configuration(),
            server: FoundationLlamaServerController(
                executableURL: URL(fileURLWithPath: helperPath)
            ),
            transport: transport,
            endpointFactory: LlamaServerEndpoint.randomLocal
        )
        try await provider.loadModel(at: URL(fileURLWithPath: modelPath))
        defer { Task { await provider.shutdown() } }

        for (index, fixture) in PublicNegationFixture.all.enumerated() {
            await qualify(fixture, index: index, provider: provider, transport: transport)
        }
    }

    private func qualify(
        _ fixture: String,
        index: Int,
        provider: HyMT2TranslationProvider,
        transport: PublicNegationRecordingTransport
    ) async {
        do {
            let result = try await provider.translate(
                TranslationRequest(
                    id: requestID(index),
                    sourceText: fixture,
                    glossary: []
                )
            )
            print("HYMT_PUBLIC_NEGATION_\(index + 1)=passed")
            print("HYMT_PUBLIC_NEGATION_TARGET_\(index + 1)=\(result.targetText)")
        } catch {
            let outputs = await transport.takeOutputs()
            printPublicOutputs(outputs, index: index)
            Issue.record("Public negation fixture \(index + 1) failed: \(error)")
            return
        }
        _ = await transport.takeOutputs()
    }

    private func printPublicOutputs(_ outputs: [String], index: Int) {
        for (attempt, output) in outputs.enumerated() {
            print("HYMT_PUBLIC_NEGATION_RAW_\(index + 1)_\(attempt + 1)=\(output)")
        }
    }

    private func requestID(_ index: Int) -> UUID {
        let suffix = String(format: "%012X", index + 1)
        guard let value = UUID(uuidString: "C0DEC0DE-2026-4A22-9000-\(suffix)") else {
            preconditionFailure("Static public matrix UUID is malformed.")
        }
        return value
    }
}

private enum PublicNegationFixture {
    static let all = [
        "救恩不是出于人的行为，而是本乎恩典。",
        "罪人得救不是靠功德，也不是靠宗教仪式。",
        "神没有忘记自己的应许。",
        "福音不可更改。",
        "门徒不能靠自己结出属灵的果子。",
        "不要惧怕，只要信。",
        "基督从未离弃属基督的人。",
        "这并非人的工作，而是圣灵的工作。",
        "没有人能因遵行律法而称义。",
        "信心若没有行为就是死的。",
        "神的应许从未落空。",
        "恩典不是纵容罪恶。",
    ]
}

private actor PublicNegationRecordingTransport: LlamaServerTransport {
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
