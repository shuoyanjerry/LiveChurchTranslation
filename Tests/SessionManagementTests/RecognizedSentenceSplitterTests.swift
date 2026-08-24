import ASRAPI
import Foundation
@testable import SessionManagement
import Testing
import TranscriptAPI

@Suite("Legacy sentence-split recovery compatibility")
struct RecognizedSentenceSplitterTests {
    @Test func unpunctuatedLongRecognitionStillBecomesOneBoundedSentence() {
        let text = String(repeating: "grace and truth ", count: 2_000)
        let slices = split(text, duration: .seconds(16.5), languageCode: "en")

        #expect(slices.count == 1)
        #expect(slices[0].utterance.text == text.trimmingCharacters(in: .whitespaces))
        #expect(slices[0].utterance.startedAt == .zero)
        #expect(slices[0].utterance.endedAt == .seconds(16.5))
        #expect(SentenceRealtimePolicy.maximumAcousticWait() == .seconds(16.5))
    }

    @Test func sentenceIdentityAndEstimatedTimingAreDeterministic() {
        let id = UUID(uuidString: "56B9BA58-0E47-44B8-91F5-B510362F575A")!
        let first = split(
            "We pray. Christ answers.",
            id: id,
            duration: .seconds(9),
            languageCode: "en"
        )
        let second = split(
            "We pray. Christ answers.",
            id: id,
            duration: .seconds(9),
            languageCode: "en"
        )

        #expect(first.map(\.utterance.sourceSegmentID) == second.map(\.utterance.sourceSegmentID))
        #expect(first[0].utterance.sourceSegmentID == id)
        #expect(first[1].utterance.sourceSegmentID != id)
        #expect(first[0].utterance.startedAt == .zero)
        #expect(first[0].utterance.endedAt <= first[1].utterance.startedAt)
        #expect(first[1].utterance.endedAt == .seconds(9))
    }

    @Test func chineseRecognitionSplitsInSourceOrder() {
        let slices = split(
            "神爱世人。我们因信称义！祂赐下平安？",
            duration: .seconds(6),
            languageCode: "zh-Hans"
        )

        #expect(slices.map(\.utterance.text) == ["神爱世人。", "我们因信称义！", "祂赐下平安？"])
        #expect(slices.map(\.isFinalInSourceSegment) == [false, false, true])
        #expect(slices[0].utterance.endedAt <= slices[1].utterance.startedAt)
        #expect(slices[1].utterance.endedAt <= slices[2].utterance.startedAt)
        #expect(slices[2].utterance.endedAt == .seconds(6))
    }

    private func split(
        _ text: String,
        id: UUID = UUID(),
        duration: Duration,
        languageCode: String
    ) -> [RecognizedSentenceSlice] {
        RecognizedSentenceSplitter.split(
            ResolvedDiscourseUtterance(
                utterance: RecognizedUtterance(
                    sourceSegmentID: id,
                    text: text,
                    confidence: 1,
                    startedAt: .zero,
                    endedAt: duration
                ),
                audit: TranscriptSourceAudit(rawText: text, corrections: []),
                pronounGuidance: []
            ),
            languageCode: languageCode
        )
    }
}
