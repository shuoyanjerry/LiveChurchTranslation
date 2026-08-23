import DiscourseResolutionAPI
import DiscourseResolutionCore
import Testing

@Suite struct DiscourseResolverCorrectionTests {
    private let resolver = DiscourseResolver()

    @Test func persistedFemaleTurnDoesNotConfirmNextReferent() {
        let result = resolve(
            "他今天会分享。",
            turns: [turn(9, "那位姐妹刚刚到了。")]
        )

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(result.ambiguities == [.noExplicitGenderAnchor])
        #expect(result.pronounGuidance.count == 1)
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
    }

    @Test func twoTurnOldMaleAppellationDoesNotConfirmReferent() {
        let result = resolve(
            "她今天会分享。",
            turns: [turn(9, "请大家安静。"), turn(8, "那位弟兄刚刚到了。")]
        )

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
    }

    @Test func usesUniqueCurrentAnchorBeforePostConnectorPronoun() {
        let text = "那位姐妹完成了见证，所以他坐下了。"
        let result = resolve(text, turns: [turn(9, "一位弟兄在等候。")])

        #expect(result.resolvedText == "那位姐妹完成了见证，所以她坐下了。")
        #expect(result.corrections.first?.reason == .uniqueCurrentTurnAnchor)
        #expect(result.corrections.first?.evidence.text == text)
    }

    @Test func currentAnchorTakesPriorityOverHistoricalGender() {
        let result = resolve(
            "母亲讲完了，然后他开始祷告。",
            turns: [turn(9, "父亲先到了。")]
        )

        #expect(result.resolvedText == "母亲讲完了，然后她开始祷告。")
    }

    @Test func auditUsesOriginalUTF16Range() {
        let prefix = "🙏 姐妹分享完了，所以 "
        let result = resolve("\(prefix)他会留下。")
        let correction = result.corrections.first

        #expect(correction?.kind == .singularGenderedPronoun)
        #expect(correction?.range == DiscourseTextRange(location: prefix.utf16.count, length: 1))
        #expect(correction?.original == "他")
        #expect(correction?.replacement == "她")
        #expect(correction?.confidence == 1)
        #expect(correction?.evidence.sequence == 10)
    }

    @Test func repairsOnlyFirstCandidateWhenLaterClauseMayChangeSubject() {
        let result = resolve("姐妹分享完了，所以他坐下。然后他喝水。")

        #expect(result.resolvedText == "姐妹分享完了，所以她坐下。然后他喝水。")
        #expect(result.corrections.count == 1)
        #expect(result.constraints == [.additionalPronounCandidatesProtected])
    }

    @Test func doesNotApplyPersistedAppellationToRepeatedCandidates() {
        let result = resolve(
            "他去过香港，因为他有亲人在当地。他了解情况，但是他没有多说。",
            turns: [turn(9, "那位老姐妹刚刚分享过。")]
        )

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(result.pronounGuidance.allSatisfy { $0.resolution == .unresolved })
    }

    @Test func doesNotRepairLaterCandidateWhenFirstAlreadyMatchesEvidence() {
        let result = resolve(
            "她先分享。然后她回应。",
            turns: [turn(9, "那位姐妹刚刚到了。")]
        )

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(result.constraints.isEmpty)
        #expect(result.pronounGuidance.count == 2)
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
        #expect(result.pronounGuidance.last?.resolution == .unresolved)
    }

    @Test func matchingGlyphDoesNotTurnPersistenceIntoEvidence() {
        let result = resolve(
            "他会继续。",
            turns: [turn(9, "那位弟兄刚刚到了。")]
        )

        #expect(result.corrections.isEmpty)
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
    }

    @Test func collectionOrderDoesNotTurnPersistedTextIntoEvidence() {
        let result = resolve(
            "他会继续。",
            turns: [turn(8, "那位姐妹到了。"), turn(9, "请大家安静。")]
        )

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
    }

    private func resolve(
        _ text: String,
        sequence: Int = 10,
        turns: [VerifiedDiscourseTurn] = []
    ) -> DiscourseResolutionResult {
        resolver.resolve(
            DiscourseResolutionRequest(
                currentSequence: sequence,
                currentText: text,
                verifiedTurns: turns
            )
        )
    }

    private func turn(_ sequence: Int, _ text: String) -> VerifiedDiscourseTurn {
        VerifiedDiscourseTurn(sequence: sequence, text: text)
    }

    private func isVerifiedFemale(_ resolution: DiscoursePronounResolution?) -> Bool {
        guard case .verified(let gender, _, _, _) = resolution else { return false }
        return gender == .female
    }

}
