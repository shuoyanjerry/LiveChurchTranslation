import Foundation
import TranscriptAPI

extension SourceOnlyPersistenceTests {
    func reviewedFirstEntry() -> TranscriptEntry {
        TranscriptEntry(
            id: UUID(),
            sequence: 1,
            sourceSegmentSequence: 41,
            rawSourceText: "她说嗯典。",
            sourceText: "她说恩典。",
            sourceCorrections: [sourceCorrection()],
            sourcePronounDecisions: [sourcePronounDecision()],
            targetText: "\(targetSentinel)_1",
            startedMilliseconds: 1_250,
            endedMilliseconds: 4_750,
            translationMilliseconds: 615,
            createdAt: Date(timeIntervalSince1970: 1_750_000_001)
        )
    }

    func reviewedSecondEntry() -> TranscriptEntry {
        TranscriptEntry(
            id: UUID(),
            sequence: 2,
            sourceSegmentSequence: 42,
            rawSourceText: "信心使我们前行。",
            sourceText: "信心使我们前行。",
            targetText: "\(targetSentinel)_2",
            startedMilliseconds: 4_751,
            endedMilliseconds: 8_900,
            translationMilliseconds: 701,
            createdAt: Date(timeIntervalSince1970: 1_750_000_002)
        )
    }

    private func sourceCorrection() -> TranscriptSourceCorrection {
        TranscriptSourceCorrection(
            observedText: "嗯典",
            replacementText: "恩典",
            kind: .recognitionNormalization,
            reason: "声学与上下文一致",
            confidence: 0.98,
            evidenceSequence: 40,
            evidenceText: "因信得恩典",
            utf16Location: 2,
            utf16Length: 2
        )
    }

    private func sourcePronounDecision() -> TranscriptSourcePronounDecision {
        TranscriptSourcePronounDecision(
            resolution: .verifiedFemale,
            utf16Location: 0,
            utf16Length: 1,
            reason: "说话者上下文",
            confidence: 0.91,
            evidenceSequence: 39,
            evidenceText: "那位姊妹"
        )
    }
}
