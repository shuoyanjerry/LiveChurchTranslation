import DiscourseResolutionAPI
import DiscourseResolutionCore
import Testing

@Suite struct DeityPronounResolutionTests {
    private let resolver = DiscourseResolver()

    @Test func deityGlyphAloneIsUnresolvedRecognizerOutput() throws {
        let result = resolve("祂赐下平安。")
        let guidance = try #require(result.pronounGuidance.first)

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(guidance.resolution == .unresolved)
        #expect(result.ambiguities == [.noExplicitDeityAnchor])
    }

    @Test func recentGodAnchorDoesNotRepairAmbiguousASRGlyph() {
        let result = resolve(
            "他赐下独生子。",
            turns: [turn(9, "神爱世人。")]
        )

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
    }

    @Test func recentGodAnchorMayClassifyUnchangedDeityGlyph() throws {
        let result = resolve(
            "祂赐下独生子。",
            turns: [turn(9, "神爱世人。")]
        )
        let guidance = try #require(result.pronounGuidance.first)

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(isVerifiedDeity(guidance.resolution))
        guard case .verifiedDeity(let reason, let confidence, let evidence) = guidance.resolution
        else { return }
        #expect(reason == .uniqueRecentDeityAnchor)
        #expect(confidence == 0.9)
        #expect(evidence.sequence == 9)
    }

    @Test func uniqueCurrentGodAnchorRepairsFollowingPronoun() {
        let result = resolve("神爱世人。然后他赐下独生子。")

        #expect(result.resolvedText == "神爱世人。然后祂赐下独生子。")
        #expect(isVerifiedDeity(result.pronounGuidance.first?.resolution))
    }

    @Test func currentHumanEvidenceOverridesDeityGlyphSpelling() {
        let result = resolve("姐妹讲完了，所以祂坐下。")

        #expect(result.resolvedText == "姐妹讲完了，所以她坐下。")
        #expect(isVerified(.female, result.pronounGuidance.first?.resolution))
    }

    @Test func godAndHumanAnchorsCompeteInsteadOfGivingGodEveryTa() {
        let result = resolve("神和弟兄都说完了，然后他继续。")

        #expect(result.resolvedText == result.originalText)
        #expect(result.ambiguities == [.competingReferentAnchors])
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
    }

    @Test func multipleDivinePersonsRemainAmbiguous() {
        let result = resolve("神和圣灵都被提到，然后他继续。")

        #expect(result.corrections.isEmpty)
        #expect(result.ambiguities == [.multipleDeityAnchors])
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
    }

    @Test func recognizesExplicitChristianDeityTerms() {
        for term in ["耶稣", "基督", "主耶稣", "圣灵", "上帝", "耶和华"] {
            let result = resolve("\(term)完成教导，然后他继续。")

            #expect(result.resolvedText.contains("然后祂继续"))
            #expect(isVerifiedDeity(result.pronounGuidance.first?.resolution))
        }
    }

    @Test func deitySubstringsDoNotBecomeReferentEvidence() {
        let nonReferentialTerms = [
            "主妇", "主义", "车主", "业主", "群主", "屋主", "债主", "苦主",
            "主人", "主讲人", "主题", "民主", "神父", "神经", "神情", "神秘",
            "神话", "神明", "神仙", "神奇", "门神", "神学", "精神", "基督徒",
            "基督教", "耶稣会", "圣灵论", "上帝视角",
        ]
        for term in nonReferentialTerms {
            let result = resolve("\(term)已经说明，然后他继续。")

            #expect(result.corrections.isEmpty)
            #expect(result.pronounGuidance.first?.resolution == .unresolved)
        }
    }

    @Test func deitySubjectDoesNotTurnHumanObjectsIntoDeityPronouns() {
        for text in [
            "神爱世人，也拯救他。",
            "耶稣呼召他跟随。",
            "神帮助他的家人。",
        ] {
            let result = resolve(text)

            #expect(result.resolvedText == result.originalText)
            #expect(result.corrections.isEmpty)
            #expect(result.pronounGuidance.first?.resolution == .unresolved)
        }
    }

    @Test func quotedDeityGlyphRemainsUnresolvedWhenTextRepairIsBlocked() {
        let result = resolve("姐妹说：“祂会来。”")

        #expect(result.constraints.contains(.quotationProtected))
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

    private func isVerifiedDeity(_ resolution: DiscoursePronounResolution?) -> Bool {
        guard case .verifiedDeity = resolution else { return false }
        return true
    }

    private func isVerified(
        _ expected: DiscourseReferentGender,
        _ resolution: DiscoursePronounResolution?
    ) -> Bool {
        guard case .verified(let gender, _, _, _) = resolution else { return false }
        return gender == expected
    }
}
