import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2MultiPronounValidationTests {
    @Test func twoUnresolvedOccurrencesRejectEitherGender() throws {
        let source = "他先说，然后她继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [
                guidance(0, .unresolvedSpokenMandarin),
                guidance(6, .unresolvedSpokenMandarin),
            ]
        )
        for values in [("he", "they"), ("they", "she"), ("he", "she")] {
            let output =
                "\(anchored(plan, 0, values.0)) spoke; "
                + "\(anchored(plan, 1, values.1)) continued."
            #expect(!validationIssues(output: output, source: source, plan: plan).isEmpty)
        }
    }

    @Test func reorderedTargetMarkersRemainBoundToTheirIDs() throws {
        let source = "她问他。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
        )
        let output = "\(anchored(plan, 1, "He")) was asked by \(anchored(plan, 0, "her"))."

        let clean = try HyMT2OutputValidator.validate(
            output,
            source: source,
            requiredTerms: [],
            pronounPlan: plan
        )

        #expect(clean == "He was asked by her.")
    }

    @Test func unrelatedUntaggedPronounCannotReplaceMissingMarker() throws {
        let source = "她问他。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
        )
        let output = "She asked \(anchored(plan, 1, "him"))."

        #expect(
            validationIssues(output: output, source: source, plan: plan).contains(
                .missingPronounMarker(
                    "P0001",
                    TranslationSourceRange(location: 0, length: 1),
                    .verifiedFemale
                )
            ))
    }
}
