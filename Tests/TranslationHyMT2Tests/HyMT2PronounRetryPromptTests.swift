import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2PronounRetryPromptTests {
    @Test func missingAnchorAddsRedactedCorrectionToStrictRetry() async throws {
        let source = "她继续。"
        let guidance = [guidance(0, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let harness = try await makeTranslationHarness(
            responses: [
                .success("She continued."),
                .success("\(anchored(plan, 0, "She")) continued."),
            ]
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            request(source: source, guidance: guidance)
        )
        let prompts = await harness.transport.completionRequests().map(\.prompt)

        #expect(result.targetText == "She continued.")
        #expect(prompts.count == 2)
        #expect(!prompts[0].contains("PRONOUN PROTOCOL CORRECTION"))
        #expect(prompts[1].contains("Failure codes: MISSING_ANCHOR"))
        #expect(prompts[1].contains("Copy every existing whole QLR protected block"))
        #expect(prompts[1].contains("REPAIR P0001"))
        #expect(prompts[1].contains("she/her/hers/herself"))
        #expect(prompts[1].components(separatedBy: plan.occurrences[0].protectedBlock).count == 2)
    }

    @Test func fidelityOnlyFailureDoesNotAddPronounCorrection() async throws {
        let source = "她在16节发言。"
        let guidance = [guidance(0, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let harness = try await makeTranslationHarness(
            responses: [
                .success("\(anchored(plan, 0, "She")) spoke."),
                .success("\(anchored(plan, 0, "She")) spoke in verse 16."),
            ]
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            request(source: source, guidance: guidance)
        )
        let prompts = await harness.transport.completionRequests().map(\.prompt)

        #expect(result.targetText == "She spoke in verse 16.")
        #expect(prompts.count == 2)
        #expect(!prompts[1].contains("PRONOUN PROTOCOL CORRECTION"))
        #expect(!prompts[1].contains("MISSING_ANCHOR"))
    }

    @Test func structuralAndPolicyFailuresUseOnlyFixedCodes() throws {
        let source = "她问他。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
        )
        let correction = try #require(
            HyMT2PronounRetryCorrection(
                issues: [
                    .duplicatePronounMarker("P0001"),
                    .pronounMarkerResolutionMismatch("P0003"),
                    .wrongPronounRealization(
                        "P0002",
                        TranslationSourceRange(location: 7, length: 1),
                        .verifiedFemale,
                        .sourceGlyph
                    ),
                ],
                plan: plan,
                source: source
            )
        )

        #expect(
            correction.codes == [
                .anchorShapeOrCardinality,
                .pronounBindingOrPolicy,
            ])
        #expect(correction.section.contains("ANCHOR_SHAPE_OR_CARDINALITY"))
        #expect(correction.section.contains("PRONOUN_BINDING_OR_POLICY"))
        #expect(correction.section.contains("audited decision encoded inside each block"))
        #expect(!correction.section.contains("P0001"))
        #expect(!correction.section.contains("REPAIR P0002"))
        #expect(!correction.section.contains("sourceGlyph"))
        #expect(!correction.section.contains("QLR_VERIFIED_FEMALE"))
    }

    private func request(
        source: String,
        guidance: [TranslationPronounGuidance]
    ) -> TranslationRequest {
        TranslationRequest(
            id: pronounTestRequestID,
            sourceText: source,
            glossary: [],
            pronounGuidance: guidance
        )
    }
}
