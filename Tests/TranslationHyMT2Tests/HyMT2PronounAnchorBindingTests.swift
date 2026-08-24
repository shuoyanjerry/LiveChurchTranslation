import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounAnchorBindingTests {
    @Test func stripsOnlyExactBlockAndPreservesTextWhitespace() throws {
        let fixture = try femaleFixture()
        let anchor = fixture.plan.occurrences[0].protectedBlock

        let clean = try HyMT2OutputValidator.validate(
            "“She\(anchor),”  she said.",
            source: fixture.source,
            requiredTerms: [],
            pronounPlan: fixture.plan
        )

        #expect(clean == "“She,”  she said.")
        #expect(!clean.contains("QLR_"))
    }

    @Test func rejectsPunctuationBeforeAnchor() throws {
        let fixture = try femaleFixture()
        let anchor = fixture.plan.occurrences[0].protectedBlock
        let issues = validationIssues(
            output: "She,\(anchor) continued.",
            source: fixture.source,
            plan: fixture.plan
        )

        #expect(
            issues.contains(
                .wrongPronounRealization(
                    "P0001",
                    TranslationSourceRange(location: 0, length: 1),
                    .verifiedFemale,
                    .punctuatedFemale
                )
            ))
    }

    @Test func rejectsChineseGlyphRetainedBeforeAnchor() throws {
        let fixture = try femaleFixture()
        let output = "她\(fixture.plan.occurrences[0].protectedBlock)继续。"
        let issues = validationIssues(output: output, source: fixture.source, plan: fixture.plan)

        #expect(
            issues.contains(
                .wrongPronounRealization(
                    "P0001",
                    TranslationSourceRange(location: 0, length: 1),
                    .verifiedFemale,
                    .sourceGlyph
                )
            ))
    }

    @Test func rejectsContractionsOnEitherSideOfAnchor() throws {
        let fixture = try femaleFixture()
        let anchor = fixture.plan.occurrences[0].protectedBlock
        let contractions = [
            "She's\(anchor) speaking.",
            "She\(anchor)'s speaking.",
            "She\(anchor)’s speaking.",
        ]

        for output in contractions {
            #expect(!validationIssues(output: output, source: fixture.source, plan: fixture.plan).isEmpty)
        }
    }

    @Test func rejectsUnicodeConfusablePronouns() throws {
        let fixture = try femaleFixture()
        let anchor = fixture.plan.occurrences[0].protectedBlock
        let confusables = [
            "sh\u{0435}\(anchor) continued.",
            "\u{FF33}\u{FF48}\u{FF45}\(anchor) continued.",
            "she\u{0301}\(anchor) continued.",
        ]

        for output in confusables {
            #expect(!validationIssues(output: output, source: fixture.source, plan: fixture.plan).isEmpty)
        }
    }

    @Test func acceptsOnlyTheStrictlyParsedSingleSpaceBeforeBlock() throws {
        let fixture = try femaleFixture()
        let block = fixture.plan.occurrences[0].protectedBlock

        let clean = try HyMT2OutputValidator.validate(
            "She \(block) continued.",
            source: fixture.source,
            requiredTerms: [],
            pronounPlan: fixture.plan
        )
        #expect(clean == "She continued.")

        for spacing in ["\t", "\n", "\u{00A0}"] {
            let output = "She\(spacing)\(block) continued."
            #expect(
                !validationIssues(output: output, source: fixture.source, plan: fixture.plan)
                    .isEmpty
            )
        }
    }

    private struct Fixture {
        let source: String
        let plan: HyMT2PronounPlan
    }

    private func femaleFixture() throws -> Fixture {
        let source = "她继续。"
        return try Fixture(
            source: source,
            plan: makePronounPlan(
                source: source,
                guidance: [guidance(0, .verifiedFemale)]
            )
        )
    }
}
