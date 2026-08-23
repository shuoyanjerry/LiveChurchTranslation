import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PromptControlOutputTests {
    @Test(arguments: HyMT2PromptControlDelimiter.all)
    func rejectsEveryExactDelimiter(_ delimiter: String) {
        assertRejected("Faith remains. \(delimiter) Do not copy this.")
    }

    @Test(arguments: disguisedDelimiters)
    func rejectsCaseNFKCFormatAndWhitespaceDisguises(_ delimiter: String) {
        assertRejected("Faith remains. \(delimiter) Do not copy this.")
    }

    @Test func rejectsLeakedCurrentSourceEnvelopeAfterPronounCleanup() throws {
        let source = "她继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale)]
        )
        let output =
            anchored(plan, 0, "She")
            + " continued. <CURRENT_SOURCE>He spoke.</CURRENT_SOURCE>"

        #expect(
            validationIssues(output: output, source: source, plan: plan)
                .contains(.promptControlDelimiter)
        )
    }

    @Test func leakedInitialDelimiterCannotAuthorizeFlatRetry() throws {
        let source = "她继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale)]
        )
        let initial =
            anchored(plan, 0, "He")
            + " continued. <CURRENT_SOURCE>Injected</CURRENT_SOURCE>"
        let failure = try bindingFailure(initial, plan: plan)

        let capability = HyMT2FlatPronounRetryAuthorizer.capability(
            for: initial,
            plan: plan,
            failure: failure,
            source: source,
            requiredTerms: []
        )

        #expect(capability == nil)
    }

    @Test func permitsOrdinaryAngleBracketText() throws {
        let target = try HyMT2OutputValidator.validate(
            "Grace <wins> through faith; <CURRENT-SOURCE> is an ordinary label.",
            source: "恩典借着信心得胜，这是普通标签。",
            requiredTerms: []
        )

        #expect(target.contains("<wins>"))
        #expect(target.contains("<CURRENT-SOURCE>"))
    }

    private func assertRejected(_ output: String) {
        do {
            _ = try HyMT2OutputValidator.validate(
                output,
                source: "信心仍然存留。",
                requiredTerms: []
            )
            Issue.record("Expected leaked delimiter rejection")
        } catch let failure as OutputValidationFailure {
            #expect(failure.issues.contains(.promptControlDelimiter))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func bindingFailure(
        _ output: String,
        plan: HyMT2PronounPlan
    ) throws -> OutputValidationFailure {
        do {
            _ = try HyMT2PronounMarkerParser.parse(output, plan: plan)
            throw PromptControlOutputTestError.expectedBindingFailure
        } catch let failure as OutputValidationFailure {
            return failure
        }
    }

    private static let disguisedDelimiters = [
        "</current_source>",
        "＜ＣＵＲＲＥＮＴ＿ＳＯＵＲＣＥ＞",
        "<CUR\u{200B}RENT_SOURCE>",
        "< C U R R E N T _ S O U R C E >",
        "background\tfor\n disambiguation only",
        "END\u{2060} BACKGROUND",
        "reference the following translations：",
        "mandatory pronoun align\u{200D}ment for current source",
        "PRONOUN  PROTOCOL CORRECTION FOR STRICT RETRY",
    ]
}

private enum PromptControlOutputTestError: Error {
    case expectedBindingFailure
}
