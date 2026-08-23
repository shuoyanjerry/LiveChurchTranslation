import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2CanonicalResidualValidationTests {
    @Test func initialCanonicalRejectsEveryResidualProtocolClass() throws {
        let fixture = try makeCanonicalResidualFixture()

        for residual in fixture.residuals {
            #expect(
                initialIssues(fixture.valid + residual, fixture: fixture)
                    .contains(.malformedPronounMarker)
            )
        }
    }

    @Test func strictCanonicalRejectsEveryResidualProtocolClass() throws {
        let fixture = try makeCanonicalResidualFixture()

        for residual in fixture.residuals {
            #expect(
                strictIssues(fixture.valid + residual, fixture: fixture)
                    .contains(.malformedPronounMarker)
            )
        }
    }

    @Test func cleanCanonicalOutputRemainsAcceptedInBothPaths() throws {
        let fixture = try makeCanonicalResidualFixture()

        let initial = try HyMT2OutputValidator.validate(
            fixture.valid,
            source: fixture.source,
            requiredTerms: [],
            pronounPlan: fixture.plan
        )
        let strict = try HyMT2OutputValidator.validated(
            fixture.valid,
            source: fixture.source,
            requiredTerms: [],
            pronounPlan: fixture.plan,
            flatRetryCapability: fixture.capability
        )

        #expect(initial == "She continued.")
        #expect(strict.target == "She continued.")
    }

    @Test func residualInitialOutputCannotAuthorizeStrictCompatibility() throws {
        let fixture = try makeCanonicalResidualFixture()
        let wrong = "\(anchored(fixture.plan, 0, "He")) continued."
        let bindingFailure = try canonicalBindingFailure(wrong, plan: fixture.plan)

        for residual in fixture.authorizationResiduals {
            let capability = HyMT2FlatPronounRetryAuthorizer.capability(
                for: wrong + residual,
                plan: fixture.plan,
                failure: bindingFailure,
                source: fixture.source,
                requiredTerms: []
            )
            #expect(capability == nil)
        }
    }

    private func initialIssues(
        _ output: String,
        fixture: CanonicalResidualFixture
    ) -> [OutputValidationIssue] {
        validationIssues(output: output, source: fixture.source, plan: fixture.plan)
    }

    private func strictIssues(
        _ output: String,
        fixture: CanonicalResidualFixture
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
            Issue.record("Unexpected error: \(error)")
            return []
        }
    }

    private func canonicalBindingFailure(
        _ output: String,
        plan: HyMT2PronounPlan
    ) throws -> OutputValidationFailure {
        do {
            _ = try HyMT2PronounMarkerParser.parse(output, plan: plan)
            throw CanonicalResidualTestError.expectedBindingFailure
        } catch let failure as OutputValidationFailure {
            return failure
        }
    }
}

private struct CanonicalResidualFixture {
    let source: String
    let plan: HyMT2PronounPlan
    let valid: String
    let capability: HyMT2FlatPronounRetryCapability

    var residuals: [String] {
        let occurrence = plan.occurrences[0]
        let nonce = String(occurrence.markerName.prefix(12))
        return [
            " \(occurrence.identifier)",
            " \(occurrence.identifier.map(String.init).joined(separator: " "))",
            " QLR_REPLAY",
            " \(nonce)",
            " &lt;/QLR",
        ]
    }

    var authorizationResiduals: [String] {
        residuals + [" P9999"]
    }
}

private func makeCanonicalResidualFixture() throws -> CanonicalResidualFixture {
    let source = "她继续。"
    let plan = try makePronounPlan(
        source: source,
        guidance: [guidance(0, .verifiedFemale)]
    )
    let wrong = "\(anchored(plan, 0, "He")) continued."
    return try CanonicalResidualFixture(
        source: source,
        plan: plan,
        valid: "\(anchored(plan, 0, "She")) continued.",
        capability: authorizedFlatRetryCapability(
            source: source,
            plan: plan,
            initialOutput: wrong
        )
    )
}

private enum CanonicalResidualTestError: Error {
    case expectedBindingFailure
}
