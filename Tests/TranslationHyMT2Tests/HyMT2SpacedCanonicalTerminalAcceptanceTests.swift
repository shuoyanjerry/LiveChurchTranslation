import Testing
@testable import TranslationHyMT2

@Suite struct HyMT2SpacedTerminalTests {
    @Test func initialValidationAcceptsExactTerminalSpacedSurface() throws {
        let source = "她继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale)]
        )
        let terminal = "she \(plan.occurrences[0].protectedBlock)"

        let atEnd = try HyMT2OutputValidator.validated(
            terminal,
            source: source,
            requiredTerms: [],
            pronounPlan: plan
        )
        let withPeriod = try HyMT2OutputValidator.validated(
            terminal + ".",
            source: source,
            requiredTerms: [],
            pronounPlan: plan
        )

        #expect(atEnd.target == "she")
        #expect(withPeriod.target == "she.")
        #expect(atEnd.pronounRealizations.map(\.realizationClass) == [.feminine])
        #expect(withPeriod.pronounRealizations.map(\.realizationClass) == [.feminine])
    }
}
