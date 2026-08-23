import DiscourseResolutionAPI
import DiscourseResolutionCore
import Testing

@Suite struct UniformGenderAnchorResolutionTests {
    private let resolver = DiscourseResolver()

    @Test func resolvesMaleWhenEveryExplicitHumanAnchorIsMale() {
        let result = resolve("弟兄和父亲都到了，所以她开始分享。")

        #expect(result.resolvedText == "弟兄和父亲都到了，所以他开始分享。")
        #expect(result.corrections.first?.reason == .uniformCurrentTurnGenderAnchors)
        #expect(isVerified(.male, result.pronounGuidance.first?.resolution))
    }

    @Test func mixedHumanGendersStillAbstain() {
        let result = resolve("姐妹和弟兄都到了，所以他开始分享。")

        #expect(result.corrections.isEmpty)
        #expect(result.ambiguities == [.competingGenderAnchors])
    }

    @Test func multipleDeityAnchorsStillAbstain() {
        let result = resolve("神和圣灵都被提到，然后他继续。")

        #expect(result.corrections.isEmpty)
        #expect(result.ambiguities == [.multipleDeityAnchors])
    }

    @Test func pluralAnchorStillAbstains() {
        let result = resolve("姐妹们和母亲都到了，所以他开始分享。")

        #expect(result.corrections.isEmpty)
        #expect(result.constraints.contains(.pluralReferenceProtected))
    }

    @Test func quotationStillBlocksUniformGenderEvidence() {
        let result = resolve("姐妹和母亲说：“他会来。”")

        #expect(result.corrections.isEmpty)
        #expect(result.constraints.contains(.quotationProtected))
    }

    @Test func uniformGenderNeverUsesAnchorsAfterCandidate() {
        let result = resolve("他先开口，姐妹和母亲随后回应。")

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(result.ambiguities == [.anchorAfterPronoun])
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
    }

    @Test func uniformGenderDoesNotMakeObjectCandidateEligible() {
        let result = resolve("姐妹和母亲向他问好。")

        #expect(result.corrections.isEmpty)
        #expect(result.constraints.contains(.ineligiblePronounPosition))
    }

    private func resolve(_ text: String) -> DiscourseResolutionResult {
        resolver.resolve(
            DiscourseResolutionRequest(
                currentSequence: 10,
                currentText: text,
                verifiedTurns: []
            )
        )
    }

    private func isVerified(
        _ expected: DiscourseReferentGender,
        _ resolution: DiscoursePronounResolution?
    ) -> Bool {
        guard case .verified(let gender, _, _, _) = resolution else { return false }
        return gender == expected
    }
}
