import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2PronounDiagnosticTests {
    @Test func classifiesObservedRealizationsWithoutRetainingText() {
        let fixtures: [(String, HyMT2ObservedPronounClass)] = [
            ("She", .female),
            ("himself", .male),
            ("THEM", .singularThey),
            (" “She,” ", .punctuatedFemale),
            ("(him!)", .punctuatedMale),
            ("—THEM?", .punctuatedSingularThey),
            ("她。", .sourceGlyph),
            ("神爱世人", .chinese),
            ("God", .singleOtherToken),
            ("she herself", .multiToken),
            ("she2", .other),
            ("  \n", .missing),
        ]

        for fixture in fixtures {
            #expect(HyMT2PronounRealizationClassifier.observe(fixture.0) == fixture.1)
        }
    }

    @Test func punctuatedPronounClassesRemainRejected() {
        #expect(
            HyMT2PronounRealizationClassifier.acceptedClass(
                .punctuatedFemale,
                for: .verifiedFemale
            ) == nil
        )
        #expect(
            HyMT2PronounRealizationClassifier.acceptedClass(
                .punctuatedMale,
                for: .verifiedMale
            ) == nil
        )
        #expect(
            HyMT2PronounRealizationClassifier.acceptedClass(
                .punctuatedSingularThey,
                for: .unresolvedSpokenMandarin
            ) == nil
        )
    }

    @Test func errorAndObserverExposeOnlyExpectedAndObservedClasses() async throws {
        let source = "她继续分享私人见证。"
        let guidance = [guidance(0, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let initial = "\(anchored(plan, 0, "he")) continued sharing."
        let strict = "\(anchored(plan, 0, "private secret")) continued sharing."
        let observer = PronounDiagnosticRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(initial), .success(strict)],
            pronounDiagnosticObserver: observer
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            TranslationRequest(
                id: pronounTestRequestID,
                sourceText: source,
                glossary: [],
                pronounGuidance: guidance
            )
        )

        #expect(result.targetText == "private secret continued sharing.")
        #expect(result.review?.issueCodes == ["quality.pronoun_alignment"])
        let observations = await observer.observations()
        #expect(observations.map(\.phase) == [.initial, .strictRetry])
        #expect(observations.map(\.expectedResolution) == [.verifiedFemale, .verifiedFemale])
        #expect(observations.map(\.observedClass) == [.male, .singleOtherToken])
        #expect(
            observations.map(\.sourceRange)
                == guidance.flatMap { [$0.sourceRange, $0.sourceRange] }
        )
    }

    @Test func absentExpectedMarkerReportsMissingClass() throws {
        let source = "她继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale)]
        )
        let issues = validationIssues(output: "She continued.", source: source, plan: plan)

        #expect(issues.first?.description == "pronoun marker P0001 expected verifiedFemale, observed missing")
    }

}

private actor PronounDiagnosticRecorder: HyMT2PronounDiagnosticObserving {
    private var recorded: [HyMT2PronounDiagnosticObservation] = []

    func record(_ observation: HyMT2PronounDiagnosticObservation) {
        recorded.append(observation)
    }

    func observations() -> [HyMT2PronounDiagnosticObservation] {
        recorded
    }
}
