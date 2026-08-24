import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounMarkerValidationTests {
    @Test func rejectsUnknownDuplicateAndMissingAnchors() throws {
        let fixture = try fixture()
        let first = anchored(fixture.plan, 0, "she")
        let second = anchored(fixture.plan, 1, "he")
        let unknown = second.replacingOccurrences(of: "P0002", with: "P9999")

        #expect(issues(first + " " + unknown, fixture).contains(.unknownPronounMarker("P9999")))
        #expect(
            issues(first + " " + first + " " + second, fixture).contains(
                .duplicatePronounMarker("P0001")
            ))
        #expect(
            issues("She spoke. " + second, fixture).contains(
                .missingPronounMarker(
                    "P0001",
                    TranslationSourceRange(location: 0, length: 1),
                    .verifiedFemale
                )
            ))
    }

    @Test func rejectsLegacyAlteredAndIncompleteBlocks() throws {
        let fixture = try fixture()
        let first = fixture.plan.occurrences[0]
        let second = anchored(fixture.plan, 1, "he")
        let firstToken = HyMT2PronounResolutionToken.value(for: first.resolution)
        let firstCode = String(HyMT2PronounResolutionToken.compactCode(for: first.resolution))
        let malformedFirstAnchors = [
            "<QLR_\(first.markerName)>她</QLR_\(first.markerName)>",
            "she<QLR_\(first.markerName)/>",
            anchored(fixture.plan, 0, "she").replacingOccurrences(of: "<Q", with: "<q"),
            "she" + String(first.protectedBlock.dropLast()),
            "she"
                + first.protectedBlock.replacingOccurrences(
                    of: "\(firstCode)>",
                    with: "\(firstCode.lowercased())>"
                ),
            "she<QLR_\(first.markerName)>KEEP</QLR_\(first.markerName)>",
            "she<QLR_\(first.markerName)></QLR_\(first.markerName)>",
            "she<QLR_\(first.markerName)>\(firstToken)\(firstToken)</QLR_\(first.markerName)>",
            "she<QLR_\(first.markerName)> \(firstToken) </QLR_\(first.markerName)>",
            "she<QLR_\(first.markerName)>\(firstToken)</QLR_111111112222_P9999>",
            "she&lt;QLR_\(first.markerName)&gt;\(firstToken)&lt;/QLR_\(first.markerName)&gt;",
            anchored(fixture.plan, 0, "she") + " \(firstToken)",
            anchored(fixture.plan, 0, "she") + " ＱＬＲ＿TOKEN",
            anchored(fixture.plan, 0, "she") + " Q\u{200B}LR_TOKEN",
            "she QLR_\(first.markerName)",
        ]

        for malformed in malformedFirstAnchors {
            #expect(issues(malformed + " " + second, fixture).contains(.malformedPronounMarker))
        }
    }

    @Test func rejectsRightWordJoinAndOnePronounForTwoAnchors() throws {
        let fixture = try fixture()
        let first = fixture.plan.occurrences[0]
        let second = fixture.plan.occurrences[1]
        let joined = "she\(first.protectedBlock)nanigans asked he\(second.protectedBlock)."
        let reused = "She\(first.protectedBlock)\(second.protectedBlock) spoke."
        let separatedReuse = "She\(first.protectedBlock) \(second.protectedBlock) spoke."
        let beforePronoun = "\(first.protectedBlock) She asked he\(second.protectedBlock)."
        let detached = "She spoke \(first.protectedBlock) to he\(second.protectedBlock)."

        #expect(!issues(joined, fixture).isEmpty)
        #expect(!issues(reused, fixture).isEmpty)
        #expect(!issues(separatedReuse, fixture).isEmpty)
        #expect(!issues(beforePronoun, fixture).isEmpty)
        #expect(!issues(detached, fixture).isEmpty)
    }

    @Test func rejectsCompactCodeThatDisagreesWithExpectedResolution() throws {
        let fixture = try fixture()
        let female = fixture.plan.occurrences[0]
        let femaleToken = String(HyMT2PronounResolutionToken.compactCode(for: .verifiedFemale))
        let maleToken = String(HyMT2PronounResolutionToken.compactCode(for: .verifiedMale))
        let changed = anchored(fixture.plan, 0, "she")
            .replacingOccurrences(of: "\(femaleToken)>", with: "\(maleToken)>")
        let output = changed + " asked " + anchored(fixture.plan, 1, "he") + "."

        #expect(
            issues(output, fixture).contains(
                .pronounMarkerResolutionMismatch(female.identifier)
            ))
    }

    @Test func markerDigitsDoNotSatisfySourceNumberValidation() throws {
        let source = "她在16节发言。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale)]
        )
        let output = "\(anchored(plan, 0, "She")) spoke in the verse."

        #expect(
            validationIssues(output: output, source: source, plan: plan).contains(
                .missingNumber("16")
            ))
    }

    private struct Fixture {
        let source: String
        let plan: HyMT2PronounPlan
    }

    private func fixture() throws -> Fixture {
        let source = "她问他。"
        return try Fixture(
            source: source,
            plan: makePronounPlan(
                source: source,
                guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
            )
        )
    }

    private func issues(
        _ output: String,
        _ fixture: Fixture
    ) -> [OutputValidationIssue] {
        validationIssues(output: output, source: fixture.source, plan: fixture.plan)
    }
}
