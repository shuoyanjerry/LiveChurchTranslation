import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounRangeValidationTests {
    @Test func zeroLocationIsValidButZeroLengthIsRejected() throws {
        let plan = try makePronounPlan(
            source: "他发言。",
            guidance: [guidance(0, .verifiedMale)]
        )
        #expect(plan.occurrences.first?.sourceGlyph == "他")
        #expect(
            plan.protectedSource
                == "他\(try #require(plan.occurrences.first).protectedBlock) 发言。"
        )

        assertIssue(
            .emptyPronounSourceRange(0),
            source: "他发言。",
            guidance: [guidance(0, .verifiedMale, length: 0)]
        )
    }

    @Test func insertsProtectedBlocksAfterGlyphsInUTF16SourceOrder() throws {
        let source = "她他😀祂"
        let plan = try makePronounPlan(
            source: source,
            guidance: [
                guidance(4, .verifiedDeity),
                guidance(0, .verifiedFemale),
                guidance(1, .verifiedMale),
            ]
        )
        let occurrences = plan.occurrences
        let expected =
            "她\(occurrences[0].protectedBlock) "
            + "他\(occurrences[1].protectedBlock)"
            + "😀祂\(occurrences[2].protectedBlock)"

        #expect(plan.protectedSource == expected)
        #expect(occurrences.map(\.sourceRange.location) == [0, 1, 4])
    }

    @Test func preservesEverySourceGlyphInModelVisibleSource() throws {
        let plan = try makePronounPlan(
            source: "他她祂他",
            guidance: [
                guidance(0, .verifiedFemale),
                guidance(1, .verifiedMale),
                guidance(2, .unresolvedSpokenMandarin),
                guidance(3, .verifiedDeity),
            ]
        )
        let visibleGlyphs = zip(
            ["他", "她", "祂", "他"],
            plan.occurrences
        ).map { glyph, occurrence in
            "\(glyph)\(occurrence.protectedBlock)"
        }

        #expect(visibleGlyphs.allSatisfy(plan.protectedSource.contains))
        #expect(plan.occurrences.map(\.sourceGlyph) == ["他", "她", "祂", "他"])
    }

    @Test func rejectsNegativeAndOutOfBoundsRanges() {
        assertIssue(
            .negativePronounSourceRange(-1, 1),
            source: "他发言。",
            guidance: [guidance(-1, .verifiedMale)]
        )
        assertIssue(
            .negativePronounSourceRange(0, -1),
            source: "他发言。",
            guidance: [guidance(0, .verifiedMale, length: -1)]
        )
        assertIssue(
            .pronounSourceRangeOutOfBounds(99, 1),
            source: "他发言。",
            guidance: [guidance(99, .verifiedMale)]
        )
    }

    @Test func rejectsSurrogateBoundaryAndWrongGlyph() {
        assertIssue(
            .pronounSourceRangeNotOnCharacterBoundary(1, 1),
            source: "😀他",
            guidance: [guidance(1, .verifiedMale)]
        )
        assertIssue(
            .pronounSourceRangeWrongGlyph(0),
            source: "神爱人。",
            guidance: [guidance(0, .verifiedDeity)]
        )
    }

    @Test func rejectsDuplicateAndOverlappingRanges() {
        assertIssue(
            .duplicatePronounSourceRange(0, 1),
            source: "他发言。",
            guidance: [guidance(0, .verifiedMale), guidance(0, .verifiedMale)]
        )
        assertIssue(
            .overlappingPronounSourceRanges(0, 1),
            source: "他她发言。",
            guidance: [
                guidance(0, .verifiedMale, length: 2),
                guidance(1, .verifiedFemale),
            ]
        )
    }

    private func assertIssue(
        _ expected: OutputValidationIssue,
        source: String,
        guidance: [TranslationPronounGuidance]
    ) {
        do {
            _ = try HyMT2PronounPlan.make(
                source: source,
                guidance: guidance,
                requestID: pronounTestRequestID
            )
            Issue.record("Expected range rejection")
        } catch let failure as OutputValidationFailure {
            #expect(failure.issues.contains(expected))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

}
