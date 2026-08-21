import Foundation
import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite("Hy-MT2 real-model qualification")
struct HyMT2RealModelSmokeTests {
    @Test(
        "translates supplied theological fixtures with the bundled helper",
        .enabled(
            if: ProcessInfo.processInfo.environment["HYMT_MODEL_DIR"] != nil
                && ProcessInfo.processInfo.environment["HYMT_LLAMA_SERVER"] != nil,
            "Requires HYMT_MODEL_DIR and HYMT_LLAMA_SERVER."
        )
    )
    func translatesTheologyWhenSupplied() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            let modelPath = environment["HYMT_MODEL_DIR"],
            let helperPath = environment["HYMT_LLAMA_SERVER"]
        else { return }
        try requireExisting(modelPath)
        try requireExisting(helperPath)

        let provider = HyMT2TranslationProvider(
            helperExecutableURL: URL(fileURLWithPath: helperPath)
        )
        try await provider.loadModel(at: URL(fileURLWithPath: modelPath))
        defer { Task { await provider.shutdown() } }

        for fixture in TheologicalGoldenFixtures.accepted {
            let result = try await provider.translate(
                TranslationRequest(
                    sourceText: fixture.source,
                    glossary: fixture.requiredTerms
                )
            )
            print("HYMT_REAL_\(fixture.name)=\(result.targetText)")
            print("HYMT_DURATION_\(fixture.name)=\(result.duration)")
            #expect(!result.targetText.isEmpty)
            for term in fixture.requiredTerms {
                #expect(
                    result.targetText.localizedCaseInsensitiveContains(term.target),
                    "Missing \(term.target)"
                )
            }
        }
    }

    private func requireExisting(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CocoaError(.fileNoSuchFile)
        }
    }
}
