import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2FlatPronounAdversarialTests {
    @Test func rejectsNonExactSeparatorsAndNormalizedProtocolLookalikes() throws {
        let fixture = try makeAdversarialFixture()
        let invalid = [
            "she  P0001 QLR_VERIFIED_FEMALE continued.",
            "she\tP0001 QLR_VERIFIED_FEMALE continued.",
            "she p0001 QLR_VERIFIED_FEMALE continued.",
            "she P0001 qlr_verified_female continued.",
            "she Ｐ０００１ ＱＬＲ＿ＶＥＲＩＦＩＥＤ＿ＦＥＭＡＬＥ continued.",
            "she P0\u{200B}001 QLR_VERIFIED_FEMALE continued.",
            "she P0001 Q\u{200B}LR_VERIFIED_FEMALE continued.",
        ]

        for output in invalid {
            #expect(adversarialIssues(output, fixture).contains(.malformedPronounMarker))
        }
    }

    @Test func rejectsUnknownDuplicateMissingAndResolutionMismatch() throws {
        let fixture = try makeAdversarialFixture()
        let valid = flatCertified(fixture.plan, 0, "she")
        let unknown = valid.replacingOccurrences(of: "P0001", with: "P9999")
        let mismatch = valid.replacingOccurrences(
            of: "QLR_VERIFIED_FEMALE",
            with: "QLR_VERIFIED_MALE"
        )

        #expect(adversarialIssues(unknown, fixture).contains(.unknownPronounMarker("P9999")))
        #expect(
            adversarialIssues(valid + " " + valid, fixture)
                .contains(.duplicatePronounMarker("P0001"))
        )
        #expect(adversarialIssues("She continued.", fixture).contains(where: isMissingP0001))
        #expect(
            adversarialIssues(mismatch, fixture).contains(
                .pronounMarkerResolutionMismatch("P0001")
            )
        )
    }

    @Test func rejectsResidualOrdinalNonceTagAndCertificateText() throws {
        let fixture = try makeAdversarialFixture()
        let valid = flatCertified(fixture.plan, 0, "she")
        let residuals = [
            valid + " P9999",
            valid + " 111111112222_P0001",
            valid + " <QLR_REPLAY>",
            valid + " QLR_UNRESOLVED",
            valid + " ｐ０００９",
            valid + " Q\u{2060}LR_REPLAY",
        ]

        for output in residuals {
            #expect(adversarialIssues(output, fixture).contains(.malformedPronounMarker))
        }
    }

    @Test func rejectsUnsafeLeftAndRightBoundaries() throws {
        let fixture = try makeAdversarialFixture()
        let valid = flatCertified(fixture.plan, 0, "she")
        let unsafe = [
            "'" + valid,
            "/" + valid,
            "-" + valid,
            "她" + valid,
            "1" + valid,
            "\u{0301}" + valid,
            valid + "'s",
            valid + "/word",
            valid + "-word",
            valid + "她",
            valid + "1",
            valid + "\u{0301}",
        ]

        for output in unsafe {
            #expect(adversarialIssues(output, fixture).contains(.malformedPronounMarker))
        }
    }

    @Test func rejectsWrongASCIIPronounEvenWithValidCertificate() throws {
        let fixture = try makeAdversarialFixture()
        let output = flatCertified(fixture.plan, 0, "he")

        #expect(
            adversarialIssues(output, fixture).contains(
                .wrongPronounRealization(
                    "P0001",
                    TranslationSourceRange(location: 0, length: 1),
                    .verifiedFemale,
                    .male
                )
            )
        )
    }
}

private struct FlatAdversarialFixture {
    let source: String
    let plan: HyMT2PronounPlan
    let capability: HyMT2FlatPronounRetryCapability
}

private func makeAdversarialFixture() throws -> FlatAdversarialFixture {
    let source = "她继续。"
    let plan = try makePronounPlan(
        source: source,
        guidance: [guidance(0, .verifiedFemale)]
    )
    let initial = "\(anchored(plan, 0, "he")) continued."
    return try FlatAdversarialFixture(
        source: source,
        plan: plan,
        capability: authorizedFlatRetryCapability(
            source: source,
            plan: plan,
            initialOutput: initial
        )
    )
}

private func adversarialIssues(
    _ output: String,
    _ fixture: FlatAdversarialFixture
) -> [OutputValidationIssue] {
    do {
        _ = try HyMT2OutputValidator.validated(
            output,
            source: fixture.source,
            requiredTerms: [],
            pronounPlan: fixture.plan,
            flatRetryCapability: fixture.capability
        )
        return []
    } catch let failure as OutputValidationFailure {
        return failure.issues
    } catch {
        return []
    }
}

private func isMissingP0001(_ issue: OutputValidationIssue) -> Bool {
    guard case .missingPronounMarker(let identifier, _, _) = issue else {
        return false
    }
    return identifier == "P0001"
}
