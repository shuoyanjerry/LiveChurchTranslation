import Testing
@testable import TranslationHyMT2

@Suite struct HyMT2PronounValidationTests {
    @Test func rejectsMasculineTranslationOfResolvedFemaleReferent() {
        assertIssue(
            .unexpectedMasculinePronoun,
            output: "He went to Hong Kong because his sister lives nearby.",
            source: "她去过香港，因为她的妹妹住在附近。"
        )
    }

    @Test func rejectsFeminineTranslationOfResolvedMaleReferent() {
        assertIssue(
            .unexpectedFemininePronoun,
            output: "She continued to share her testimony.",
            source: "他继续分享他的见证。"
        )
    }

    @Test func acceptsNeutralTheyForUnresolvedSourceGender() throws {
        let output = try HyMT2OutputValidator.validate(
            "They continued to share the testimony.",
            source: "他继续分享这个见证。",
            requiredTerms: []
        )

        #expect(output.hasPrefix("They"))
    }

    @Test func protectedLexemeDoesNotHideIndependentMalePronoun() {
        for source in [
            "他告诉其他人。",
            "他帮助他人。",
            "吉他手说他会继续。",
        ] {
            assertIssue(
                .unexpectedFemininePronoun,
                output: "She continued speaking to the others.",
                source: source
            )
        }
    }

    @Test func protectedLexemeAloneIsNotTreatedAsMalePronoun() {
        let found = issues(
            output: "She continued to share.",
            source: "其他人继续分享。"
        )

        #expect(!found.contains(.unexpectedFemininePronoun))
    }

    private func assertIssue(
        _ expected: OutputValidationIssue,
        output: String,
        source: String
    ) {
        #expect(issues(output: output, source: source).contains(expected))
    }

    private func issues(output: String, source: String) -> [OutputValidationIssue] {
        do {
            _ = try HyMT2OutputValidator.validate(
                output,
                source: source,
                requiredTerms: []
            )
            return []
        } catch let failure as OutputValidationFailure {
            return failure.issues
        } catch {
            Issue.record("Unexpected error: \(error)")
            return []
        }
    }
}
