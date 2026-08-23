import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2OutputValidatorTests {
    @Test func acceptsTermsNumbersNegationAndScriptureReference() throws {
        let output = try HyMT2OutputValidator.validate(
            "John 3:16 does not teach justification by works, but salvation by grace.",
            source: "约翰福音3章16节没有教导靠行为称义，而是靠恩典得救。",
            requiredTerms: [
                TranslationTerm(source: "恩典", target: "grace")
            ]
        )

        #expect(output.hasPrefix("John 3:16"))
    }

    @Test func rejectsMissingRequiredTerm() {
        assertIssue(
            .missingTerm("justification by faith"),
            output: "We are justified.",
            source: "我们因信称义。",
            terms: [
                TranslationTerm(source: "因信称义", target: "justification by faith")
            ]
        )
    }

    @Test func acceptsApprovedGrammaticalVariantForRequiredTerm() throws {
        let result = try HyMT2OutputValidator.validate(
            "We are justified by faith.",
            source: "我们因信称义。",
            requiredTerms: [
                TranslationTerm(
                    source: "因信称义",
                    target: "justification by faith",
                    acceptedTargets: ["justified by faith"]
                )
            ]
        )

        #expect(result == "We are justified by faith.")
    }

    @Test func preferredTermGuidesModelWithoutRejectingNaturalOutput() throws {
        let result = try HyMT2OutputValidator.validate(
            "We serve one another.",
            source: "我们彼此事奉。",
            requiredTerms: [
                TranslationTerm(
                    source: "事奉",
                    target: "ministry",
                    requirement: .preferred
                )
            ]
        )

        #expect(result == "We serve one another.")
    }

    @Test func rejectsMissingNumberAndMalformedReference() {
        let issues = issues(
            output: "John chapter 3 records this truth.",
            source: "约翰福音3章16节记载了这个真理。"
        )

        #expect(issues.contains(.missingNumber("16")))
        #expect(issues.contains(.malformedScriptureReference))
    }

    @Test func rejectsLostNegation() {
        assertIssue(
            .missingNegation,
            output: "God abandons His people.",
            source: "神永不离弃祂的百姓。"
        )
    }

    @Test func rejectsModelCommentary() {
        assertIssue(
            .metaText,
            output: "Here is the translation: Grace saves us.",
            source: "恩典拯救我们。"
        )
    }

    @Test func rejectsReservedProtocolTextWithoutPronounGuidance() {
        assertIssue(
            .promptControlDelimiter,
            output: "Grace is enough. QLR_PRIVATE",
            source: "恩典够用。"
        )
    }

    @Test(arguments: ["They 后来继续分享。", "They continued sharing。"])
    func rejectsChineseSourceScriptInEnglishOutput(_ output: String) {
        assertIssue(
            .unexpectedSourceScript,
            output: output,
            source: "他后来继续分享。"
        )
    }

    @Test func acceptsChineseNumeralScriptureReferenceRenderedConventionally() throws {
        let result = try HyMT2OutputValidator.validate(
            "John 3:16 proclaims God's love.",
            source: "约翰福音三章十六节宣告神的爱。",
            requiredTerms: []
        )

        #expect(result == "John 3:16 proclaims God's love.")
    }

    private func assertIssue(
        _ expected: OutputValidationIssue,
        output: String,
        source: String,
        terms: [TranslationTerm] = []
    ) {
        #expect(issues(output: output, source: source, terms: terms).contains(expected))
    }

    private func issues(
        output: String,
        source: String,
        terms: [TranslationTerm] = []
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
            Issue.record("Unexpected error: \(error)")
            return []
        }
    }
}
