import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2ContextReplayDetectorTests {
    @Test func detectsNormalizedExactCopy() {
        let context = entry(
            "Faith remains our anchor when the world around us changes without warning."
        )
        let candidate = "ＦＡＩＴＨ remains—OUR anchor; when the world around us changes without warning!"

        #expect(detect(candidate, context: [context]) == .normalizedExact)
    }

    @Test func detectsExactCopyFromAnyRecentEntry() {
        let copied = entry(
            "Prayer keeps our hearts steady while circumstances continue to change around us."
        )
        let newest = entry(
            "The newest context discusses a separate subject and should not match this candidate."
        )

        #expect(detect(copied.targetText, context: [copied, newest]) == .normalizedExact)
    }

    @Test func detectsNormalizedChineseExactCopy() {
        let context = entry(
            "在动荡变化的世界中，我们仍然可以借着祷告彼此扶持，耐心等候神的带领，"
                + "并在每天的生活里持守真实的盼望。"
        )
        let candidate =
            "在动荡变化的世界中　我们仍然可以借着祷告彼此扶持；耐心等候神的带领，"
            + "并在每天的生活里持守真实的盼望！"

        #expect(detect(candidate, context: [context]) == .normalizedExact)
    }

    @Test func detectsLongHighOverlapCopy() {
        let context = entry(
            "Through Abraham's story, let us reflect on where our sense of security comes from: "
                + "work, routines, relationships, income, and familiar surroundings."
        )
        let candidate =
            "Through Abraham's story, let us also reflect on where our sense of security comes "
            + "from: work, routines, relationships, income, and familiar surroundings."

        #expect(detect(candidate, context: [context]) == .highOverlap)
    }

    @Test func allowsRepeatedShortHeading() {
        let context = entry("Scripture: Covenant and Promise")

        #expect(detect("SCRIPTURE — COVENANT & PROMISE", context: [context]) == nil)
    }

    @Test func allowsRepeatedShortScriptureReference() {
        let context = entry("John 3:16 — God loved the world.")

        #expect(detect("John 3:16: God loved the world", context: [context]) == nil)
    }

    @Test func allowsRepeatedCommonTerminology() {
        let context = entry("Grace and peace in Jesus Christ")

        #expect(detect("Grace and peace in Jesus Christ.", context: [context]) == nil)
    }

    @Test func rejectsLongTextsWithOnlySharedBoilerplate() {
        let context = entry(
            "Brothers and sisters, today we gather in faith to consider Abraham's long journey "
                + "through the wilderness and the promise that guided his household."
        )
        let candidate =
            "Brothers and sisters, today we gather in faith to consider Paul's pastoral counsel "
            + "about forgiveness, reconciliation, and life together in the church."

        #expect(detect(candidate, context: [context]) == nil)
    }

    @Test func ignoresAContextSourceMatch() {
        let context = TranslationContextEntry(
            sourceText: "The candidate repeats this sufficiently long source sentence exactly.",
            targetText: "The prior target discusses an unrelated and sufficiently detailed subject."
        )

        #expect(detect(context.sourceText, context: [context]) == nil)
    }

    @Test func rejectsLongRepetitionWithInsufficientInformationDiversity() {
        let repeated = Array(repeating: "amen", count: 24).joined(separator: " ")

        #expect(detect(repeated, context: [entry(repeated)]) == nil)
    }

    @Test func rejectsAnExcerptFromAConsiderablyLongerContext() {
        let candidate =
            "Prayer helps us remain faithful while we wait for guidance through difficult seasons."
        let context = entry(
            candidate + " The congregation also serves its neighbors, supports families, and "
                + "continues teaching Scripture throughout the year."
        )

        #expect(detect(candidate, context: [context]) == nil)
    }

    @Test func ignoresEmptyAndPunctuationOnlyCandidates() {
        let context = entry(
            "A sufficiently long context translation exists only to exercise empty input handling."
        )

        #expect(detect("", context: [context]) == nil)
        #expect(detect("—— …… !!!", context: [context]) == nil)
    }

    private func detect(
        _ candidate: String,
        context: [TranslationContextEntry]
    ) -> HyMT2ContextReplayKind? {
        HyMT2ContextReplayDetector.detect(
            candidateTarget: candidate,
            recentContext: context
        )
    }

    private func entry(_ target: String) -> TranslationContextEntry {
        TranslationContextEntry(sourceText: "先前内容", targetText: target)
    }
}
