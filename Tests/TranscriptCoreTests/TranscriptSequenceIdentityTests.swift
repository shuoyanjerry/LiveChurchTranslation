import ASRAPI
import Foundation
import Testing
import TranscriptAPI
import TranscriptCore
import TranslationAPI

@Suite struct TranscriptSequenceIdentityTests {
    @Test func presentationOrderStaysDenseAcrossFilteredAndFailedGaps() async throws {
        let buffer = LiveTranscriptBuffer()
        await buffer.begin(sessionID: UUID(), at: Date())

        for sourceSequence in [UInt64(1), UInt64(3), UInt64(5)] {
            let recognition = RecognizedUtterance(
                sourceSegmentID: UUID(),
                text: "讲道",
                confidence: nil,
                startedAt: .zero,
                endedAt: .seconds(1)
            )
            let entry = try await buffer.makeEntry(
                recognition: recognition,
                translation: TranslationResult(
                    requestID: UUID(),
                    sourceText: "讲道",
                    targetText: "sermon",
                    duration: .milliseconds(10)
                ),
                sourceAudit: TranscriptSourceAudit(rawText: "讲道", corrections: []),
                sourceSegmentSequence: sourceSequence
            )
            await buffer.append(entry)
        }

        let entries = await buffer.snapshot()?.entries ?? []
        #expect(entries.map(\.sequence) == [1, 2, 3])
        #expect(entries.compactMap(\.sourceSegmentSequence) == [1, 3, 5])
    }
}
