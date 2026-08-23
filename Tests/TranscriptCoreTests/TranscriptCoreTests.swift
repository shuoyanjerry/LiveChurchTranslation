import ASRAPI
import Foundation
import Testing
import TranscriptAPI
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

    @Test func auditedEntryPreservesRawRecognizerOutput() async throws {
        let buffer = LiveTranscriptBuffer()
        await buffer.begin(sessionID: UUID(), at: Date())
        let entry = try await buffer.makeEntry(
            recognition: fixtureRecognition(text: "救恩来自恩典"),
            translation: fixtureTranslation(text: "Salvation comes from grace."),
            sourceAudit: TranscriptSourceAudit(
                rawText: "休恩来自恩典",
                corrections: [
                    TranscriptSourceCorrection(
                        observedText: "休恩",
                        replacementText: "救恩"
                    )
                ],
                pronounDecisions: [
                    TranscriptSourcePronounDecision(
                        resolution: .unresolvedSpokenMandarin,
                        utf16Location: 0,
                        utf16Length: 1
                    )
                ]
            )
        )

        #expect(entry.rawSourceText == "休恩来自恩典")
        #expect(entry.sourceText == "救恩来自恩典")
        #expect(entry.sourceCorrections.first?.observedText == "休恩")
        #expect(entry.sourcePronounDecisions.first?.resolution == .unresolvedSpokenMandarin)
    }

    @Test func backendReviewEvidenceSurvivesBufferAndJSONRoundTrip() async throws {
        let buffer = LiveTranscriptBuffer()
        await buffer.begin(sessionID: UUID(), at: Date())
        let review = TranslationReview(issueCodes: [
            "quality.missing_negation", "quality.missing_required_term",
        ])
        let entry = try await buffer.makeEntry(
            recognition: fixtureRecognition(text: "我们不是靠行为得救。"),
            translation: TranslationResult(
                requestID: UUID(),
                sourceText: "我们不是靠行为得救。",
                targetText: "We are saved by works.",
                duration: .milliseconds(20),
                review: review
            )
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(TranscriptEntry.self, from: data)

        #expect(decoded.targetText == "We are saved by works.")
        #expect(decoded.translationReview == review)
    }

    @Test func legacyEntryJSONDefaultsRawTextToNormalizedText() throws {
        let entry = TranscriptEntry(
            sequence: 1,
            sourceText: "救恩",
            targetText: "salvation",
            startedMilliseconds: 0,
            endedMilliseconds: 100,
            translationMilliseconds: 10
        )
        let current = try JSONEncoder().encode(entry)
        var object = try #require(
            JSONSerialization.jsonObject(with: current) as? [String: Any]
        )
        object.removeValue(forKey: "rawSourceText")
        object.removeValue(forKey: "sourceCorrections")
        object.removeValue(forKey: "sourcePronounDecisions")
        object.removeValue(forKey: "translationReview")
        let legacy = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(TranscriptEntry.self, from: legacy)
        #expect(decoded.sourceSegmentSequence == nil)
        #expect(decoded.rawSourceText == "救恩")
        #expect(decoded.sourceCorrections.isEmpty)
        #expect(decoded.sourcePronounDecisions.isEmpty)
        #expect(decoded.translationReview == nil)
    }

    @Test func legacyCorrectionJSONDefaultsStructuredAuditFields() throws {
        let legacy = Data(#"{"observedText":"他","replacementText":"她"}"#.utf8)

        let decoded = try JSONDecoder().decode(TranscriptSourceCorrection.self, from: legacy)

        #expect(decoded.observedText == "他")
        #expect(decoded.replacementText == "她")
        #expect(decoded.kind == nil)
        #expect(decoded.reason == nil)
        #expect(decoded.confidence == nil)
        #expect(decoded.evidenceSequence == nil)
        #expect(decoded.evidenceText == nil)
        #expect(decoded.utf16Location == nil)
        #expect(decoded.utf16Length == nil)
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
