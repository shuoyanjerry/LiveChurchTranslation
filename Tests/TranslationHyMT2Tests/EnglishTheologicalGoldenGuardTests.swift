import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct EnglishTheologicalGoldenGuardTests {
    @Test(arguments: EnglishTheologicalGoldenFixtures.accepted)
    func humanReviewedTranslationsPass(fixture: EnglishTheologicalGoldenFixture) throws {
        let result = try HyMT2OutputValidator.validate(
            fixture.faithfulChinese,
            source: fixture.source,
            requiredTerms: fixture.requiredTerms,
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )

        #expect(result == fixture.faithfulChinese)
    }

    @Test(arguments: EnglishTheologicalGoldenFixtures.accepted)
    func promptPinsDirectionAndTerms(fixture: EnglishTheologicalGoldenFixture) {
        let prompt = HyMT2PromptBuilder.prompt(
            source: fixture.source,
            targetLanguage: "zh-Hans",
            sourceLanguage: "en",
            terms: fixture.requiredTerms,
            strict: true
        )

        #expect(prompt.contains("into Simplified Chinese"))
        #expect(prompt.contains("without summarizing, adding, or omitting"))
        #expect(prompt.contains("约翰福音 3:16"))
        #expect(!prompt.contains("Spoken Mandarin tā"))
        for term in fixture.requiredTerms {
            #expect(prompt.contains("\(term.source) translates to \(term.target)"))
        }
    }

    @Test func rejectsLostNegationNumberAndRequiredTerm() {
        let issues = validationIssues(
            output: "救恩来自人的行为。",
            source: "Salvation in John 3:16 is not earned by works.",
            terms: [EnglishTheologicalGoldenFixtures.salvation]
        )

        #expect(issues.contains(.missingNegation))
        #expect(issues.contains(.missingNumber("3")))
        #expect(issues.contains(.missingNumber("16")))
        #expect(issues.contains(.malformedScriptureReference))
    }

    @Test func canonicalizesSafeCunpssShenOrthography() throws {
        let result = try HyMT2OutputValidator.validate(
            "上帝 赐下祂的兒子，彰显神의作为。",
            source: "God gave His Son.",
            requiredTerms: [EnglishTheologicalGoldenFixtures.god],
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )

        #expect(result == "神赐下祂的儿子，彰显神的作为。")
    }

    @Test(arguments: ["神은信实的。", "神の作为。"])
    func rejectsForeignScriptContamination(output: String) {
        let issues = validationIssues(
            output: output,
            source: "God gives grace.",
            terms: []
        )

        #expect(issues.contains(.unexpectedSourceScript))
    }

    @Test func bilingualContextUsesTheCorrectDirection() {
        let prompt = HyMT2PromptBuilder.prompt(
            source: "He gives us grace.",
            targetLanguage: "zh-Hans",
            sourceLanguage: "en",
            terms: [],
            context: [
                TranslationContextEntry(
                    sourceText: "God is faithful.",
                    targetText: "神是信实的。"
                )
            ],
            strict: false
        )

        #expect(prompt.contains("English: \"God is faithful.\""))
        #expect(prompt.contains("Chinese: \"神是信实的。\""))
    }

    private func validationIssues(
        output: String,
        source: String,
        terms: [TranslationTerm]
    ) -> [OutputValidationIssue] {
        HyMT2FidelityValidator.issues(
            target: output,
            source: source,
            requiredTerms: terms,
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )
    }
}
