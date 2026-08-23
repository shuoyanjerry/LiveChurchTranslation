import Foundation
import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite("Hy-MT2 public protocol diagnostics")
struct HyMT2PublicProtocolDiagnosticTests {
    @Test(
        "records model surface output for the hard-coded public fixture",
        .enabled(
            if: ProcessInfo.processInfo.environment["HYMT_PUBLIC_PROTOCOL_DIAGNOSTIC"] == "1",
            "Requires an explicit public-only diagnostic opt in."
        )
    )
    func recordsPublicFixtureOnly() async throws {
        let environment = ProcessInfo.processInfo.environment
        let modelPath = try #require(environment["HYMT_MODEL_DIR"])
        let helperPath = try #require(environment["HYMT_LLAMA_SERVER"])
        let transport = PublicOutputRecordingTransport()
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

        do {
            _ = try await provider.translate(publicRequest())
        } catch {
            print("HYMT_PUBLIC_PROTOCOL_RESULT=rejected")
        }
        let outputs = await transport.recordedOutputs()
        for (index, output) in outputs.enumerated() {
            print("HYMT_PUBLIC_PROTOCOL_RAW_\(index + 1)=\(output)")
        }
        #expect(outputs.count == 2)
    }

    private func publicRequest() throws -> TranslationRequest {
        let requestID = try #require(
            UUID(uuidString: "A1B2C3D4-E5F6-47A8-9B0C-D1E2F3A4B5C6")
        )
        return TranslationRequest(
            id: requestID,
            sourceText: "她去过香港，因为她有亲人在新加坡。她知道我英文不好，但是她仍然努力和我交流。",
            glossary: [],
            context: [
                TranslationContextEntry(
                    sourceText: "一位老姐妹告诉我，她在这个教会聚会很多年了。",
                    targetText:
                        "An elderly sister told me that she had attended this church for many years."
                )
            ],
            pronounGuidance: [0, 8, 17, 28].map { location in
                TranslationPronounGuidance(
                    sourceRange: TranslationSourceRange(location: location, length: 1),
                    resolution: .verifiedFemale
                )
            }
        )
    }
}

private actor PublicOutputRecordingTransport: LlamaServerTransport {
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

    func recordedOutputs() -> [String] {
        outputs
    }
}
