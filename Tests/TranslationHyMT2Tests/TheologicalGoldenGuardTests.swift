import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct TheologicalGoldenGuardTests {
    @Test(arguments: TheologicalGoldenFixtures.accepted)
    func humanAuthoredFaithfulSentencesPassValidator(
        fixture: TheologicalGoldenFixture
    ) throws {
        let result = try HyMT2OutputValidator.validate(
            fixture.faithfulEnglish,
            source: fixture.source,
            requiredTerms: fixture.requiredTerms
        )

        #expect(result == fixture.faithfulEnglish)
    }

    @Test(arguments: TheologicalGoldenFixtures.accepted)
    func promptPinsEveryApplicableTheologicalTerm(
        fixture: TheologicalGoldenFixture
    ) {
        let glossary =
            TheologicalGoldenFixtures.userRequestedTerms
            + TheologicalGoldenFixtures.contextualTerms
            + [TheologicalGoldenFixtures.unrelated]
        let matched = TranslationTermMatcher.matched(
            in: fixture.source,
            from: glossary,
            limit: 64
        )
        let prompt = HyMT2PromptBuilder.prompt(
            source: fixture.source,
            targetLanguage: "en",
            terms: matched,
            strict: true
        )

        #expect(Set(matched) == Set(fixture.requiredTerms))
        for term in fixture.requiredTerms {
            #expect(prompt.contains("\(term.source) translates to \(term.target)"))
        }
        #expect(!prompt.contains("大使命 translates to the Great Commission"))
        #expect(prompt.contains("without summarizing, adding, or omitting"))
        #expect(prompt.hasSuffix(fixture.source))
    }

    @Test(arguments: TheologicalGoldenFixtures.userRequestedTerms)
    func validatorRejectsOmissionOfEveryRequiredUserTerm(
        term: TranslationTerm
    ) {
        let issues = validationIssues(
            output: "The sermon clearly explains this doctrine.",
            source: "讲道清楚说明\(term.source)的真理。",
            terms: [term]
        )

        #expect(issues.contains(.missingTerm(term.target)))
    }

    @Test func scriptureGuardRejectsLostNegationAndVerseNumber() {
        let fixture = TheologicalGoldenFixtures.accepted[2]
        let lostNegation = validationIssues(
            output: "Ephesians 2:8 teaches that salvation is by grace through faith and comes from works.",
            source: fixture.source,
            terms: fixture.requiredTerms
        )
        let lostVerse = validationIssues(
            output:
                "Ephesians chapter 2 teaches that salvation is by grace through faith and is not from works.",
            source: fixture.source,
            terms: fixture.requiredTerms
        )

        #expect(lostNegation.contains(.missingNegation))
        #expect(lostVerse.contains(.missingNumber("8")))
        #expect(lostVerse.contains(.malformedScriptureReference))
    }

    private func validationIssues(
        output: String,
        source: String,
        terms: [TranslationTerm]
    ) -> [OutputValidationIssue] {
        do {
            _ = try HyMT2OutputValidator.validate(
                output,
                source: source,
                requiredTerms: terms
            )
            return []
        } catch let failure as OutputValidationFailure {
            return failure.issues
        } catch {
            Issue.record("Unexpected validation error: \(error)")
            return []
        }
    }
}
