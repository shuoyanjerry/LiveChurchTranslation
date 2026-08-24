import Foundation
import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2TerminalSpacedAdversarialTests {
    @Test func rejectsMissingNonPronounAndWrongClassBindings() throws {
        let fixture = try makeTerminalFixture()
        let block = fixture.plan.occurrences[0].protectedBlock
        let invalid = [
            "\(block).",
            "because \(block).",
            "for \(block).",
            "he \(block).",
        ]

        for output in invalid {
            #expect(!terminalIssues(output, fixture).isEmpty)
        }
    }

    @Test func rejectsTerminalShapeBeforeAnotherBlock() throws {
        let fixture = try makeTwoOccurrenceTerminalFixture()
        let output =
            "she \(fixture.plan.occurrences[0].protectedBlock). "
            + "He \(fixture.plan.occurrences[1].protectedBlock)"

        #expect(terminalIssues(output, fixture).contains(.malformedPronounMarker))
    }

    @Test func exactCanonicalUsesCurrentPlanInsteadOfFlatCapability() throws {
        let fixture = try makeTerminalFixture()
        let otherID = try #require(
            UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")
        )
        let otherPlan = try #require(
            try HyMT2PronounPlan.make(
                source: fixture.source,
                guidance: [guidance(0, .verifiedFemale)],
                requestID: otherID
            )
        )
        let output = "she \(otherPlan.occurrences[0].protectedBlock)."

        #expect(terminalIssues(output, fixture, planOverride: otherPlan).isEmpty)
    }

    @Test func rejectsZeroGapAndFlatHybrids() throws {
        let fixture = try makeTwoOccurrenceTerminalFixture()
        let second = "him \(fixture.plan.occurrences[1].protectedBlock)."
        let zeroGap = "\(anchored(fixture.plan, 0, "she")) asked \(second)"
        let flat = "\(flatCertified(fixture.plan, 0, "she")) asked \(second)"

        #expect(terminalIssues(zeroGap, fixture).contains(.malformedPronounMarker))
        #expect(terminalIssues(flat, fixture).contains(.malformedPronounMarker))
    }

    @Test func rejectsUnknownDuplicateNonceAndResolutionTampering() throws {
        let fixture = try makeTerminalFixture()
        let valid = "she \(fixture.plan.occurrences[0].protectedBlock)."
        let unknown = valid.replacingOccurrences(of: "P0001", with: "P9001")
        let duplicate = valid + " she \(fixture.plan.occurrences[0].protectedBlock)."
        let wrongNonce = valid.replacingOccurrences(
            of: String(fixture.plan.occurrences[0].markerName.prefix(12)),
            with: "ABCDEF123456"
        )
        let wrongResolution = valid.replacingOccurrences(
            of: "\(HyMT2PronounResolutionToken.compactCode(for: .verifiedFemale))>",
            with: "\(HyMT2PronounResolutionToken.compactCode(for: .verifiedMale))>"
        )

        for output in [unknown, duplicate, wrongNonce, wrongResolution] {
            #expect(!terminalIssues(output, fixture).isEmpty)
        }
    }

    @Test func finalFidelityStillRejectsControlAndChineseText() throws {
        let fixture = try makeTerminalFixture()
        let terminal = "she \(fixture.plan.occurrences[0].protectedBlock)."

        #expect(
            terminalIssues("<CURRENT_SOURCE> \(terminal)", fixture)
                .contains(.promptControlDelimiter)
        )
        #expect(
            terminalIssues("中文 \(terminal)", fixture)
                .contains(.unexpectedSourceScript)
        )
    }
}

private struct TerminalAdversarialFixture {
    let source: String
    let plan: HyMT2PronounPlan
    let capability: HyMT2FlatPronounRetryCapability
}

private func makeTerminalFixture() throws -> TerminalAdversarialFixture {
    let source = "她继续。"
    let plan = try makePronounPlan(
        source: source,
        guidance: [guidance(0, .verifiedFemale)]
    )
    return try terminalFixture(
        source: source,
        plan: plan,
        initial: "\(anchored(plan, 0, "he")) continued."
    )
}

private func makeTwoOccurrenceTerminalFixture() throws -> TerminalAdversarialFixture {
    let source = "她问他。"
    let plan = try makePronounPlan(
        source: source,
        guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
    )
    let initial = "\(anchored(plan, 0, "he")) asked \(anchored(plan, 1, "her"))."
    return try terminalFixture(source: source, plan: plan, initial: initial)
}

private func terminalFixture(
    source: String,
    plan: HyMT2PronounPlan,
    initial: String
) throws -> TerminalAdversarialFixture {
    try TerminalAdversarialFixture(
        source: source,
        plan: plan,
        capability: authorizedFlatRetryCapability(
            source: source,
            plan: plan,
            initialOutput: initial
        )
    )
}

private func terminalIssues(
    _ output: String,
    _ fixture: TerminalAdversarialFixture,
    planOverride: HyMT2PronounPlan? = nil
) -> [OutputValidationIssue] {
    do {
        _ = try HyMT2OutputValidator.validated(
            output,
            source: fixture.source,
            requiredTerms: [],
            pronounPlan: planOverride ?? fixture.plan,
            flatRetryCapability: fixture.capability
        )
        return []
    } catch let failure as OutputValidationFailure {
        return failure.issues
    } catch {
        return []
    }
}
