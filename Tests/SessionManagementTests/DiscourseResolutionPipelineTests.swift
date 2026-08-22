import AudioCaptureAPI
@testable import SessionManagement
import Testing
import TranscriptAPI

@Suite struct DiscourseResolutionPipelineTests {
    @Test func persistedFemaleAnchorCorrectsNextTurnAndKeepsAudit() async throws {
        let harness = SessionTestHarness(
            recognizedTexts: [
                "那位姐妹分享了她的见证。",
                "他后来继续讲述救恩。",
            ],
            emitsEveryFrame: true,
            audioFrames: Self.frames
        )

        let events = try await harness.run()

        #expect(events.appendedEntries.count == 2)
        let corrected = try #require(events.appendedEntries.last)
        #expect(corrected.rawSourceText == "他后来继续讲述救恩。")
        #expect(corrected.sourceText == "她后来继续讲述救恩。")
        let audit = try #require(
            corrected.sourceCorrections.first { $0.kind == .discoursePronoun }
        )
        #expect(audit.observedText == "他")
        #expect(audit.replacementText == "她")
        #expect(audit.reason == "uniqueRecentVerifiedAnchor")
        #expect(audit.evidenceSequence == 1)
        #expect(audit.evidenceText == "那位姐妹分享了她的见证。")
        #expect(audit.utf16Location == 0)
        #expect(audit.utf16Length == 1)
        #expect(await harness.translator.receivedRequests().last?.sourceText == corrected.sourceText)
        #expect(await harness.store.persistedEntries().last == corrected)
    }

    private static let frames = [
        frame(at: .zero),
        frame(at: .seconds(1)),
    ]

    private static func frame(at timestamp: Duration) -> AudioFrame {
        AudioFrame(
            samples: Array(repeating: 0.25, count: 320),
            sampleRate: 16_000,
            channelCount: 1,
            timestamp: timestamp
        )
    }
}
