import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2SpacedCanonicalValidationTests {
    @Test func initialValidationAcceptsStrictlyParsedSpacedCanonicalSurface() throws {
        let fixture = try makeSpacedFixture()
        let output = spacedOutput(fixture.plan)

        let validated = try initialSpacedValidation(output, fixture)

        #expect(validated.target == "She asked him to reply.")
        #expect(validated.pronounRealizations.map(\.realizationClass) == [.feminine, .masculine])
    }

    @Test func authorizedStrictValidationPreservesOnePostSpace() throws {
        let fixture = try makeSpacedFixture()
        let output = spacedOutput(fixture.plan)

        let validated = try validateSpaced(output, fixture)

        #expect(validated.target == "She asked him to reply.")
        #expect(validated.pronounRealizations.map(\.realizationClass) == [.feminine, .masculine])
    }

    @Test func allZeroGapCanonicalSurfaceRemainsAccepted() throws {
        let fixture = try makeSpacedFixture()
        let output =
            "\(anchored(fixture.plan, 0, "She")) asked "
            + "\(anchored(fixture.plan, 1, "him")) to reply."

        #expect(try validateSpaced(output, fixture).target == "She asked him to reply.")
    }

    @Test func rejectsZeroGapSpacedAndCanonicalFlatHybrids() throws {
        let fixture = try makeSpacedFixture()
        let mixedGap =
            "\(spacedCanonical(fixture.plan, 0, "She"))asked "
            + "\(anchored(fixture.plan, 1, "him")) to reply."
        let mixedFlat =
            "\(spacedCanonical(fixture.plan, 0, "She"))asked "
            + "\(flatCertified(fixture.plan, 1, "him")) to reply."

        #expect(spacedIssues(mixedGap, fixture).contains(.malformedPronounMarker))
        #expect(spacedIssues(mixedFlat, fixture).contains(.malformedPronounMarker))
    }

    @Test func reorderedOccurrencesRemainBoundIndependently() throws {
        let fixture = try makeSpacedFixture()
        let output =
            "\(spacedCanonical(fixture.plan, 1, "He"))was asked by "
            + "\(spacedCanonical(fixture.plan, 0, "her"))today."

        #expect(try validateSpaced(output, fixture).target == "He was asked by her today.")
    }

    @Test func unresolvedOccurrenceAcceptsOnlySpacedSingularThey() throws {
        let source = "他继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .unresolvedSpokenMandarin)]
        )
        let initial = "\(anchored(plan, 0, "he")) continued."
        let fixture = try SpacedCanonicalFixture(
            source: source,
            plan: plan,
            capability: authorizedFlatRetryCapability(
                source: source,
                plan: plan,
                initialOutput: initial
            )
        )
        let output = spacedCanonical(plan, 0, "they") + "continued."

        #expect(try validateSpaced(output, fixture).target == "they continued.")
    }

    @Test func acceptsOnlyExactTerminalPeriodOrEndOfOutput() throws {
        let fixture = try makeSpacedFixture()
        let prefix = "\(spacedCanonical(fixture.plan, 0, "She"))asked "
        let final = "him \(fixture.plan.occurrences[1].protectedBlock)"

        let withPeriod = try validateSpaced(prefix + final + ".", fixture)
        let atEnd = try validateSpaced(prefix + final, fixture)

        #expect(withPeriod.target == "She asked him.")
        #expect(atEnd.target == "She asked him")
        #expect(
            withPeriod.pronounRealizations.map(\.realizationClass)
                == [.feminine, .masculine]
        )
    }
}

private struct SpacedCanonicalFixture {
    let source: String
    let plan: HyMT2PronounPlan
    let capability: HyMT2FlatPronounRetryCapability
}

private func makeSpacedFixture() throws -> SpacedCanonicalFixture {
    let source = "她问他。"
    let plan = try makePronounPlan(
        source: source,
        guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
    )
    let initial = "\(anchored(plan, 0, "he")) asked \(anchored(plan, 1, "him"))."
    return try SpacedCanonicalFixture(
        source: source,
        plan: plan,
        capability: authorizedFlatRetryCapability(
            source: source,
            plan: plan,
            initialOutput: initial
        )
    )
}

private func spacedOutput(_ plan: HyMT2PronounPlan) -> String {
    "\(spacedCanonical(plan, 0, "She"))asked \(spacedCanonical(plan, 1, "him"))to reply."
}

private func validateSpaced(
    _ output: String,
    _ fixture: SpacedCanonicalFixture
) throws -> HyMT2ValidatedOutput {
    try HyMT2OutputValidator.validated(
        output,
        source: fixture.source,
        requiredTerms: [],
        pronounPlan: fixture.plan,
        flatRetryCapability: fixture.capability
    )
}

private func initialSpacedValidation(
    _ output: String,
    _ fixture: SpacedCanonicalFixture
) throws -> HyMT2ValidatedOutput {
    try HyMT2OutputValidator.validated(
        output,
        source: fixture.source,
        requiredTerms: [],
        pronounPlan: fixture.plan
    )
}

private func spacedIssues(
    _ output: String,
    _ fixture: SpacedCanonicalFixture
) -> [OutputValidationIssue] {
    do {
        _ = try validateSpaced(output, fixture)
        return []
    } catch let failure as OutputValidationFailure {
        return failure.issues
    } catch {
        return []
    }
}
