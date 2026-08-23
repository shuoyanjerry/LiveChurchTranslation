import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounRetryTargetingTests {
    @Test func exactPlanMatchedIssueEmitsOnlyOrdinalAndAllowlist() throws {
        let source = "她问他。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
        )
        let occurrence = plan.occurrences[1]
        let correction = try #require(
            HyMT2PronounRetryCorrection(
                issues: [
                    .wrongPronounRealization(
                        occurrence.identifier,
                        occurrence.sourceRange,
                        occurrence.resolution,
                        .singleOtherToken
                    )
                ],
                plan: plan,
                source: source
            )
        )

        #expect(correction.section.contains("REPAIR P0002"))
        #expect(correction.section.contains("he/him/his/himself"))
        #expect(!correction.section.contains("singleOtherToken"))
        #expect(!correction.section.contains(occurrence.markerName))
        #expect(!correction.section.contains(occurrence.protectedBlock))
        #expect(!correction.section.contains(source))
    }

    @Test func sourceRangeOrResolutionMismatchCannotSelectAnOrdinal() throws {
        let source = "她问他。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
        )
        let correction = try #require(
            HyMT2PronounRetryCorrection(
                issues: [
                    .wrongPronounRealization(
                        "P0002",
                        TranslationSourceRange(location: 0, length: 1),
                        .verifiedMale,
                        .female
                    )
                ],
                plan: plan,
                source: source
            )
        )

        #expect(!correction.section.contains("REPAIR P0002"))
    }

    @Test func possessiveRuleIsDerivedWithoutCopyingSourceOrMarker() throws {
        let source = "姐妹说他会帮助他，也会为他的家人祷告。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [
                guidance(3, .verifiedFemale),
                guidance(7, .verifiedMale),
                guidance(12, .verifiedMale),
            ]
        )
        let correction = try #require(
            HyMT2PronounRetryCorrection(
                issues: [.duplicatePronounMarker("P0001")],
                plan: plan,
                source: source
            )
        )

        #expect(correction.section.contains("POSSESSIVE P0003: Use his"))
        #expect(!correction.section.contains("POSSESSIVE P0001"))
        #expect(!correction.section.contains("POSSESSIVE P0002"))
        #expect(!correction.section.contains(plan.occurrences[2].markerName))
        #expect(!correction.section.contains(plan.occurrences[2].protectedBlock))
        #expect(!correction.section.contains(source))
    }

    @Test func outputLeakUsesOnlyGenericRedactedRule() throws {
        let correction = try #require(
            HyMT2PronounRetryCorrection(
                issues: [.promptControlDelimiter],
                plan: nil,
                source: "private source"
            )
        )

        #expect(correction.codes == [.outputOnly])
        #expect(correction.section.contains("Omit every prompt section label"))
        #expect(!correction.section.contains("private source"))
    }
}
