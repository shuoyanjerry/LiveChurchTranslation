import DiscourseResolutionAPI
import DiscourseResolutionCore
import Testing

@Suite struct DiscourseResolverAbstentionTests {
    private let resolver = DiscourseResolver()

    @Test func abstainsForCompetingGenderAnchors() {
        let result = resolve("姐妹和弟兄都到了，所以他开始分享。")

        #expect(result.resolvedText == result.originalText)
        #expect(result.ambiguities == [.competingGenderAnchors])
    }

    @Test func resolvesGenderWhenEveryExplicitHumanAnchorIsFemale() {
        let result = resolve("姐妹和母亲都到了，所以他开始分享。")

        #expect(result.resolvedText == "姐妹和母亲都到了，所以她开始分享。")
        #expect(result.corrections.first?.reason == .uniformCurrentTurnGenderAnchors)
        #expect(result.ambiguities.isEmpty)
    }

    @Test func abstainsWhenEligibleCandidatesUseMixedSpellings() {
        let result = resolve(
            "她先作见证。然后他回应。",
            turns: [turn(9, "那位弟兄刚刚到了。")]
        )

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(result.ambiguities == [.mixedPronounSpellings])
    }

    @Test func protectsQuotedSpeech() {
        let result = resolve("姐妹说：“他会来。”")

        #expect(result.corrections.isEmpty)
        #expect(result.constraints.contains(.quotationProtected))
    }

    @Test func protectsPluralPronounsAndAnchors() {
        let pluralPronoun = resolve("他们会来。", turns: [turn(9, "姐妹到了。")])
        let pluralAnchor = resolve("他会来。", turns: [turn(9, "姐妹们到了。")])

        #expect(pluralPronoun.corrections.isEmpty)
        #expect(pluralPronoun.constraints.contains(.pluralReferenceProtected))
        #expect(pluralAnchor.corrections.isEmpty)
        #expect(pluralAnchor.constraints.contains(.pluralReferenceProtected))
    }

    @Test func protectsLexicalOccurrencesContainingTa() {
        for text in ["他人需要帮助。", "其他事情以后再说。", "吉他已经调好了。"] {
            let result = resolve(text, turns: [turn(9, "姐妹到了。")])
            #expect(result.resolvedText == text)
            #expect(result.constraints.contains(.lexicalOccurrenceProtected))
        }
    }

    @Test func doesNotRewriteObjectOrUseLaterProposalObjectAsAnchor() {
        let object = resolve("弟兄向她求婚。")
        let laterAnchor = resolve("她向弟兄求婚。")
        let laterClause = resolve("弟兄向她求婚，所以她答应了。")

        #expect(object.resolvedText == "弟兄向她求婚。")
        #expect(object.constraints == [.ineligiblePronounPosition])
        #expect(laterAnchor.resolvedText == "她向弟兄求婚。")
        #expect(laterAnchor.ambiguities == [.anchorAfterPronoun])
        #expect(laterClause.resolvedText == "弟兄向她求婚，所以她答应了。")
        #expect(laterClause.constraints == [.ineligiblePronounPosition])
    }

    @Test func ignoresStaleEvidenceBeyondTwoSequenceSteps() {
        let result = resolve("他会继续。", turns: [turn(7, "姐妹到了。")])

        #expect(result.corrections.isEmpty)
        #expect(result.ambiguities == [.noExplicitGenderAnchor])
        #expect(result.constraints.contains(.staleContextIgnored))
    }

    @Test func rejectsDuplicateCurrentAndFutureContextSequences() {
        let duplicate = resolve(
            "他会继续。",
            turns: [turn(9, "姐妹到了。"), turn(9, "请安静。")]
        )
        let current = resolve("他会继续。", turns: [turn(10, "姐妹到了。")])
        let future = resolve("他会继续。", turns: [turn(11, "姐妹到了。")])

        #expect(duplicate.constraints == [.outOfOrderContext])
        #expect(current.constraints == [.outOfOrderContext])
        #expect(future.constraints == [.outOfOrderContext])
        #expect(duplicate.corrections.isEmpty && current.corrections.isEmpty)
        #expect(future.corrections.isEmpty)
    }

    @Test func rejectsContextWindowLargerThanTwo() {
        let result = resolve(
            "他会继续。",
            turns: [turn(9, "姐妹到了。"), turn(8, "请安静。"), turn(7, "请坐。")]
        )

        #expect(result.constraints == [.contextLimitExceeded])
        #expect(result.corrections.isEmpty)
    }

    @Test func neverInfersGenderFromNamesOrOccupations() {
        let result = resolve("他会继续。", turns: [turn(9, "医生王芳到了。")])

        #expect(result.resolvedText == "他会继续。")
        #expect(result.ambiguities == [.noExplicitGenderAnchor])
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
    }

    @Test func objectPronounIsExplicitlyUnresolvedInsteadOfTrustingGlyph() {
        let result = resolve("弟兄向她求婚。")

        #expect(result.pronounGuidance.count == 1)
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
        #expect(result.pronounGuidance.first?.range == DiscourseTextRange(location: 3, length: 1))
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
}
