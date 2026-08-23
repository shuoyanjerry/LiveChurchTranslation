import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2StrictRetrySpacedValidationTests {
    @Test func strictRetryAcceptsExactSpacedBlocksWithoutFlatCapability() throws {
        let fixture = try makeStrictSpacedFixture()
        let output =
            "\(spacedCanonical(fixture.plan, 0, "She"))asked "
            + "\(spacedCanonical(fixture.plan, 1, "him"))to reply."

        let validated = try strictSpacedValidation(output, fixture)

        #expect(validated.target == "She asked him to reply.")
        #expect(validated.pronounRealizations.map(\.realizationClass) == [.feminine, .masculine])
    }

    @Test func initialValidationStillRejectsExactSpacedBlocks() throws {
        let fixture = try makeStrictSpacedFixture()
        let output =
            "\(spacedCanonical(fixture.plan, 0, "She"))asked "
            + "\(spacedCanonical(fixture.plan, 1, "him"))to reply."

        #expect(!validationIssues(output: output, source: fixture.source, plan: fixture.plan).isEmpty)
    }

    @Test func strictRetryStillRejectsFlatCertificatesWithoutCapability() throws {
        let fixture = try makeStrictSpacedFixture()
        let output =
            "\(flatCertified(fixture.plan, 0, "She")) asked "
            + "\(flatCertified(fixture.plan, 1, "him"))."

        #expect(strictSpacedIssues(output, fixture).contains(.malformedPronounMarker))
    }

    @Test func strictRetryAcceptsAndPreservesExactCommaContinuation() throws {
        let fixture = try makeStrictSpacedFixture()
        let output =
            "\(spacedCanonical(fixture.plan, 0, "She"))asked "
            + "him \(fixture.plan.occurrences[1].protectedBlock), and prayed."

        let validated = try strictSpacedValidation(output, fixture)

        #expect(validated.target == "She asked him, and prayed.")
        #expect(validated.pronounRealizations.map(\.realizationClass) == [.feminine, .masculine])
    }

    @Test func commaContinuationRejectsNonExactOrUnsafeSurfaces() throws {
        let fixture = try makeSingleStrictSpacedFixture()
        let stem = "she \(fixture.plan.occurrences[0].protectedBlock)"
        let invalid = [
            stem + ",and continued.",
            stem + ",  and continued.",
            stem + "， and continued.",
            stem + ", \u{200B}and continued.",
            stem + ", 'and continued.",
            stem + ", 1 continued.",
            stem + ",, and continued.",
        ]

        for output in invalid {
            #expect(strictSpacedIssues(output, fixture).contains(.malformedPronounMarker))
        }
    }
}

private struct StrictSpacedFixture {
    let source: String
    let plan: HyMT2PronounPlan
}

private func makeStrictSpacedFixture() throws -> StrictSpacedFixture {
    let source = "她问他。"
    return try StrictSpacedFixture(
        source: source,
        plan: makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
        )
    )
}

private func makeSingleStrictSpacedFixture() throws -> StrictSpacedFixture {
    let source = "她继续。"
    return try StrictSpacedFixture(
        source: source,
        plan: makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale)]
        )
    )
}

private func strictSpacedValidation(
    _ output: String,
    _ fixture: StrictSpacedFixture
) throws -> HyMT2ValidatedOutput {
    try HyMT2OutputValidator.validated(
        output,
        source: fixture.source,
        requiredTerms: [],
        pronounPlan: fixture.plan,
        strictRetry: true
    )
}

private func strictSpacedIssues(
    _ output: String,
    _ fixture: StrictSpacedFixture
) -> [OutputValidationIssue] {
    do {
        _ = try strictSpacedValidation(output, fixture)
        return []
    } catch let failure as OutputValidationFailure {
        return failure.issues
    } catch {
        return []
    }
}
