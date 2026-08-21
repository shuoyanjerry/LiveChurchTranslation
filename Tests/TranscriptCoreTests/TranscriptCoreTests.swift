import ASRAPI
import Foundation
import Testing
import TranscriptCore
import TranslationAPI

@Suite struct TranscriptCoreTests {
    @Test func appendPreservesCompleteHistory() async throws {
        let buffer = LiveTranscriptBuffer()
        let sessionID = UUID()
        await buffer.begin(sessionID: sessionID, at: Date())
        for index in 1...3 {
            let entry = try await buffer.makeEntry(
                recognition: fixtureRecognition(text: "中文\(index)"),
                translation: fixtureTranslation(text: "English \(index)")
            )
            await buffer.append(entry)
        }
        let snapshot = await buffer.snapshot()
        #expect(snapshot?.entries.map(\.sequence) == [1, 2, 3])
        #expect(snapshot?.entries.last?.targetText == "English 3")
    }

    private func fixtureRecognition(text: String) -> RecognizedUtterance {
        RecognizedUtterance(
            sourceSegmentID: UUID(), text: text, confidence: nil,
            startedAt: .zero, endedAt: .seconds(1)
        )
    }

    private func fixtureTranslation(text: String) -> TranslationResult {
        TranslationResult(
            requestID: UUID(), sourceText: "中文", targetText: text,
            duration: .milliseconds(20)
        )
    }
}
