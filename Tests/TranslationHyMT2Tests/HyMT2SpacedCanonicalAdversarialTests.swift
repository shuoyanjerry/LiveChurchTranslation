import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2SpacedCanonicalAdversarialTests {
    @Test func rejectsNonExactPreAndPostSpacing() throws {
        let fixture = try makeSpacedAdversarialFixture()
        let block = fixture.plan.occurrences[0].protectedBlock
        let invalid = [
            "she  \(block) continues.",
            "she\t\(block) continues.",
            "she\n\(block) continues.",
            "she\u{00A0}\(block) continues.",
            "she \(block)continues.",
            "she \(block)  continues.",
            "she \(block)\tcontinues.",
            "she \(block)\ncontinues.",
            "she \(block)\u{00A0}continues.",
            "she \(block) \u{200B}continues.",
        ]

        for output in invalid {
            #expect(!spacedAdversarialIssues(output, fixture).isEmpty)
        }
    }

    @Test func rejectsUnsupportedTerminalSuffixes() throws {
        let fixture = try makeSpacedAdversarialFixture()
        let stem = "she \(fixture.plan.occurrences[0].protectedBlock)"
        let invalid = [
            stem + " ", stem + "\n", stem + "\t", stem + "\u{200B}",
            stem + " .", stem + ". ", stem + ".\n", stem + ".\u{200B}",
            stem + ". text", stem + "..", stem + ",", stem + ";", stem + ":",
            stem + "!", stem + "?", stem + "…", stem + "。",
        ]

        for output in invalid {
            #expect(!spacedAdversarialIssues(output, fixture).isEmpty)
        }
    }

    @Test func rejectsUnsafePronounBoundaries() throws {
        let fixture = try makeSpacedAdversarialFixture()
        let valid = spacedCanonical(fixture.plan, 0, "she") + "continues."
        for prefix in ["'", "/", "-", "她", "1", "\u{0301}"] {
            #expect(!spacedAdversarialIssues(prefix + valid, fixture).isEmpty)
        }
    }

    @Test func rejectsEveryNormalizedResidualProtocolFragment() throws {
        let fixture = try makeSpacedAdversarialFixture()
        let valid = spacedCanonical(fixture.plan, 0, "she") + "continues."
        let namespace = String(fixture.plan.occurrences[0].markerName.prefix(12))
        let residuals = [
            " P9999", " p00", " QLR_", " Q\u{200B}LR_", " ＱＬＲ＿",
            " \(namespace)", " ABCDEF123456", " &lt;/QLR", " <QL", " </Q",
        ]

        for residual in residuals {
            #expect(
                spacedAdversarialIssues(valid + residual, fixture)
                    .contains(.malformedPronounMarker)
            )
        }
    }

    @Test func rejectsOnePronounAttemptingToSpanTwoBlocks() throws {
        let source = "她问他。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
        )
        let initial = "\(anchored(plan, 0, "he")) asked \(anchored(plan, 1, "him"))."
        let fixture = try SpacedAdversarialFixture(
            source: source,
            plan: plan,
            capability: authorizedFlatRetryCapability(
                source: source,
                plan: plan,
                initialOutput: initial
            )
        )
        let output =
            "she \(plan.occurrences[0].protectedBlock) "
            + "\(plan.occurrences[1].protectedBlock) continues."

        #expect(spacedAdversarialIssues(output, fixture).contains(.malformedPronounMarker))
    }
}

private struct SpacedAdversarialFixture {
    let source: String
    let plan: HyMT2PronounPlan
    let capability: HyMT2FlatPronounRetryCapability
}

private func makeSpacedAdversarialFixture() throws -> SpacedAdversarialFixture {
    let source = "她继续。"
    let plan = try makePronounPlan(
        source: source,
        guidance: [guidance(0, .verifiedFemale)]
    )
    let initial = "\(anchored(plan, 0, "he")) continued."
    return try SpacedAdversarialFixture(
        source: source,
        plan: plan,
        capability: authorizedFlatRetryCapability(
            source: source,
            plan: plan,
            initialOutput: initial
        )
    )
}

private func spacedAdversarialIssues(
    _ output: String,
    _ fixture: SpacedAdversarialFixture
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
