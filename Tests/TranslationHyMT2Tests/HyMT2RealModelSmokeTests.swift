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
        try await translateUnresolvedPronounFixture(with: provider)
        try await translateDeityPronounFixture(with: provider)
        try await translateEnglishTheologyFixtures(with: provider)
    }

    private func translateEnglishTheologyFixtures(
        with provider: HyMT2TranslationProvider
    ) async throws {
        for (index, fixture) in EnglishTheologicalGoldenFixtures.accepted.enumerated() {
            do {
                let result = try await provider.translate(
                    TranslationRequest(
                        sourceText: fixture.source,
                        sourceLanguage: "en",
                        targetLanguage: "zh-Hans",
                        glossary: fixture.requiredTerms
                    )
                )
                print("HYMT_REAL_EN_ZH_\(index + 1)=\(result.targetText)")
                print("HYMT_DURATION_EN_ZH_\(index + 1)=\(result.duration)")
                #expect(
                    result.targetText.unicodeScalars.contains {
                        $0.properties.isIdeographic
                    }
                )
                for term in fixture.requiredTerms where term.requirement == .required {
                    let accepted = [term.target] + term.acceptedTargets
                    #expect(
                        accepted.contains { result.targetText.contains($0) },
                        "Missing one of \(accepted)"
                    )
                }
            } catch {
                print("HYMT_REAL_EN_ZH_\(index + 1)_ERROR=\(error)")
                Issue.record(
                    "English→Chinese fixture \(index + 1) failed: \(error)"
                )
            }
        }
    }
}

extension HyMT2RealModelSmokeTests {
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
        let requestID = try #require(
            UUID(uuidString: "A1B2C3D4-E5F6-47A8-9B0C-D1E2F3A4B5C6")
        )
        let pronounResult = try await provider.translate(
            TranslationRequest(
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
                pronounGuidance: [
                    guidance(location: 0, .verifiedFemale),
                    guidance(location: 8, .verifiedFemale),
                    guidance(location: 17, .verifiedFemale),
                    guidance(location: 28, .verifiedFemale),
                ]
            )
        )
        print("HYMT_REAL_PRONOUN=\(pronounResult.targetText)")
        let words = pronounResult.targetText.lowercased().split { !$0.isLetter }
        #expect(words.contains("she"))
        #expect(!words.contains("he"))
        #expect(!words.contains("his"))
    }

    private func translateUnresolvedPronounFixture(
        with provider: HyMT2TranslationProvider
    ) async throws {
        let result = try await provider.translate(
            TranslationRequest(
                sourceText: "他后来继续分享这个见证。",
                glossary: [],
                pronounGuidance: [guidance(.unresolvedSpokenMandarin)]
            )
        )
        print("HYMT_REAL_UNRESOLVED_PRONOUN=\(result.targetText)")
        print("HYMT_DURATION_UNRESOLVED_PRONOUN=\(result.duration)")
        let words = Set(result.targetText.lowercased().split { !$0.isLetter })
        #expect(words.contains("they"))
        #expect(words.isDisjoint(with: ["he", "him", "his", "she", "her", "hers"]))
    }

    private func translateDeityPronounFixture(
        with provider: HyMT2TranslationProvider
    ) async throws {
        let result = try await provider.translate(
            TranslationRequest(
                sourceText: "神爱世人。祂赐下独生子。",
                glossary: [],
                pronounGuidance: [guidance(location: 5, .verifiedDeity)]
            )
        )
        print("HYMT_REAL_DEITY_PRONOUN=\(result.targetText)")
        print("HYMT_DURATION_DEITY_PRONOUN=\(result.duration)")
        let words = Set(result.targetText.lowercased().split { !$0.isLetter })
        #expect(words.isDisjoint(with: ["she", "her", "hers", "they", "them", "their"]))
    }

    private func guidance(
        location: Int = 0,
        _ resolution: TranslationPronounResolution
    ) -> TranslationPronounGuidance {
        TranslationPronounGuidance(
            sourceRange: TranslationSourceRange(location: location, length: 1),
            resolution: resolution
        )
    }

}
