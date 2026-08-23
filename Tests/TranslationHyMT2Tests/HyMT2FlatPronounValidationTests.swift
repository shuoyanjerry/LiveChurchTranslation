import Foundation
import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2FlatPronounValidationTests {
    @Test func normalValidationNeverAcceptsFlatCertificates() throws {
        let fixture = try makeValidationFixture()
        let output = flatValidationOutput(fixture.plan)

        #expect(
            validationIssues(output: output, source: fixture.source, plan: fixture.plan)
                .contains(.malformedPronounMarker)
        )
    }

    @Test func authorizedStrictValidationStripsOnlyCertificates() throws {
        let fixture = try makeValidationFixture()
        let capability = try validationCapability(fixture)
        let output =
            "\(flatCertified(fixture.plan, 0, "She")), then "
            + "\(flatCertified(fixture.plan, 1, "him")) replied!"

        let validated = try HyMT2OutputValidator.validated(
            output,
            source: fixture.source,
            requiredTerms: [],
            pronounPlan: fixture.plan,
            flatRetryCapability: capability
        )

        #expect(validated.target == "She, then him replied!")
        #expect(validated.pronounRealizations.map(\.realizationClass) == [.feminine, .masculine])
    }

    @Test func authorizedStrictValidationStillAcceptsCanonicalSurface() throws {
        let fixture = try makeValidationFixture()
        let capability = try validationCapability(fixture)
        let output =
            "\(anchored(fixture.plan, 0, "She")) asked "
            + "\(anchored(fixture.plan, 1, "him"))."

        let validated = try strictValidation(output, fixture, capability)

        #expect(validated.target == "She asked him.")
    }

    @Test func rejectsHybridCanonicalAndFlatSurface() throws {
        let fixture = try makeValidationFixture()
        let capability = try validationCapability(fixture)
        let hybrid =
            "\(anchored(fixture.plan, 0, "She")) asked "
            + "\(flatCertified(fixture.plan, 1, "him"))."
        let canonicalWithResidual =
            "\(anchored(fixture.plan, 0, "She")) asked "
            + "\(anchored(fixture.plan, 1, "him")) P9999."

        #expect(
            strictValidationIssues(hybrid, fixture, capability)
                .contains(.malformedPronounMarker)
        )
        #expect(
            strictValidationIssues(canonicalWithResidual, fixture, capability)
                .contains(.malformedPronounMarker)
        )
    }

    @Test func capabilityIsBoundToExactRequestPlan() throws {
        let fixture = try makeValidationFixture()
        let capability = try validationCapability(fixture)
        let otherID = try #require(
            UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")
        )
        let otherPlan = try #require(
            try HyMT2PronounPlan.make(
                source: fixture.source,
                guidance: fixture.guidance,
                requestID: otherID
            )
        )

        #expect(
            strictValidationIssues(
                flatValidationOutput(otherPlan),
                fixture,
                capability,
                plan: otherPlan
            )
            .contains(.malformedPronounMarker)
        )
    }
}

private struct FlatValidationFixture {
    let source: String
    let guidance: [TranslationPronounGuidance]
    let plan: HyMT2PronounPlan
}

private func makeValidationFixture() throws -> FlatValidationFixture {
    let source = "她问他。"
    let guidance = [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
    return try FlatValidationFixture(
        source: source,
        guidance: guidance,
        plan: makePronounPlan(source: source, guidance: guidance)
    )
}

private func validationCapability(
    _ fixture: FlatValidationFixture
) throws -> HyMT2FlatPronounRetryCapability {
    let initial =
        "\(anchored(fixture.plan, 0, "he")) asked "
        + "\(anchored(fixture.plan, 1, "him"))."
    return try authorizedFlatRetryCapability(
        source: fixture.source,
        plan: fixture.plan,
        initialOutput: initial
    )
}

private func flatValidationOutput(_ plan: HyMT2PronounPlan) -> String {
    "\(flatCertified(plan, 0, "She")) asked \(flatCertified(plan, 1, "him"))."
}

private func strictValidation(
    _ output: String,
    _ fixture: FlatValidationFixture,
    _ capability: HyMT2FlatPronounRetryCapability,
    plan: HyMT2PronounPlan? = nil
) throws -> HyMT2ValidatedOutput {
    try HyMT2OutputValidator.validated(
        output,
        source: fixture.source,
        requiredTerms: [],
        pronounPlan: plan ?? fixture.plan,
        flatRetryCapability: capability
    )
}

private func strictValidationIssues(
    _ output: String,
    _ fixture: FlatValidationFixture,
    _ capability: HyMT2FlatPronounRetryCapability,
    plan: HyMT2PronounPlan? = nil
) -> [OutputValidationIssue] {
    do {
        _ = try strictValidation(output, fixture, capability, plan: plan)
        return []
    } catch let failure as OutputValidationFailure {
        return failure.issues
    } catch {
        return []
    }
}
