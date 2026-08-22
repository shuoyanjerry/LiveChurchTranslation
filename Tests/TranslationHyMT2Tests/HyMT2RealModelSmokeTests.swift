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
        guard let provider = try await loadedProvider(environment: environment) else { return }
        defer { Task { await provider.shutdown() } }

        try await translateGoldenFixtures(with: provider)
        try await translatePronounFixture(with: provider)
    }

    private func translateGoldenFixtures(
        with provider: HyMT2TranslationProvider
    ) async throws {
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

    private func translatePronounFixture(
        with provider: HyMT2TranslationProvider
    ) async throws {
        let pronounResult = try await provider.translate(
            TranslationRequest(
                sourceText: "她去过香港，因为她有亲人在新加坡。她知道我英文不好，但是她仍然努力和我交流。",
                glossary: [],
                context: [
                    TranslationContextEntry(
                        sourceText: "一位老姐妹告诉我，她在这个教会聚会很多年了。",
                        targetText:
                            "An elderly sister told me that she had attended this church for many years."
                    )
                ]
            )
        )
        print("HYMT_REAL_PRONOUN=\(pronounResult.targetText)")
        let words = pronounResult.targetText.lowercased().split { !$0.isLetter }
        #expect(words.contains("she"))
        #expect(!words.contains("he"))
        #expect(!words.contains("his"))
    }

    private func loadedProvider(
        environment: [String: String]
    ) async throws -> HyMT2TranslationProvider? {
        guard
            let modelPath = environment["HYMT_MODEL_DIR"],
            let helperPath = environment["HYMT_LLAMA_SERVER"]
        else { return nil }
        try requireExisting(modelPath)
        try requireExisting(helperPath)
        let provider = HyMT2TranslationProvider(
            helperExecutableURL: URL(fileURLWithPath: helperPath)
        )
        try await provider.loadModel(at: URL(fileURLWithPath: modelPath))
        return provider
    }

    private func requireExisting(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CocoaError(.fileNoSuchFile)
        }
    }
}
