import AudioCaptureAPI
@testable import SessionManagement
import SessionManagementAPI
import Testing
import TranscriptAPI
import TranslationAPI

@Suite struct DiscourseResolutionPipelineTests {
    @Test func historicalFemaleAnchorDoesNotAuthorizeGenderCorrection() async throws {
        let harness = SessionTestHarness(
            recognizedTexts: [
                "那位姐妹分享了她的见证。",
                "他后来继续讲述救恩。",
            ],
            emitsEveryFrame: true,
            audioFrames: Self.frames
        )

        let events = try await harness.run()

        try await verifySafeFemaleAbstention(events: events, harness: harness)
    }

    private func verifySafeFemaleAbstention(
        events: [LiveSessionEvent],
        harness: SessionTestHarness
    ) async throws {
        #expect(events.appendedEntries.count == 2)
        let entry = try #require(events.appendedEntries.last)
        #expect(entry.rawSourceText == "他后来继续讲述救恩。")
        #expect(entry.sourceText == entry.rawSourceText)
        #expect(entry.sourceCorrections.allSatisfy { $0.kind != .discoursePronoun })
        let decision = try #require(entry.sourcePronounDecisions.first)
        #expect(decision.resolution == .unresolvedSpokenMandarin)
        #expect(decision.evidenceSequence == nil)
        #expect(decision.evidenceText == nil)
        #expect(await harness.translator.receivedRequests().last?.sourceText == entry.sourceText)
        #expect(
            await harness.translator.receivedRequests().last?.pronounGuidance.first?.resolution
                == .unresolvedSpokenMandarin
        )
        let asrRequests = await harness.asr.receivedRequests()
        #expect(asrRequests.count == 2)
        #expect(asrRequests[0].contextPrompt == asrRequests[1].contextPrompt)
        #expect(!asrRequests[1].contextPrompt.contains("那位姐妹"))
        #expect(!asrRequests[1].contextPrompt.contains("她后来"))
        #expect(await harness.store.appendedEntries().last == entry)
    }

    @Test func unresolvedSpokenTaReachesTranslatorWithoutTrustingGlyph() async throws {
        let harness = SessionTestHarness(recognizedText: "他继续分享。")

        _ = try await harness.run()

        let request = await harness.translator.receivedRequests().last
        #expect(request?.pronounGuidance.count == 1)
        #expect(request?.pronounGuidance.first?.resolution == .unresolvedSpokenMandarin)
        let appended = await harness.store.appendedEntries().last
        #expect(appended?.rawSourceText == "他继续分享。")
        #expect(appended?.sourceText == "他继续分享。")
        #expect(
            appended?.sourcePronounDecisions.first?.resolution
                == .unresolvedSpokenMandarin
        )
    }

    @Test func historicalDeityAnchorDoesNotAuthorizeHumanGlyph() async throws {
        let harness = SessionTestHarness(
            recognizedTexts: ["神爱世人。", "他赐下独生子。"],
            emitsEveryFrame: true,
            audioFrames: Self.frames
        )

        let events = try await harness.run()

        let entry = try #require(events.appendedEntries.last)
        #expect(entry.rawSourceText == "他赐下独生子。")
        #expect(entry.sourceText == entry.rawSourceText)
        #expect(entry.sourcePronounDecisions.first?.resolution == .unresolvedSpokenMandarin)
        #expect(
            await harness.translator.receivedRequests().last?.pronounGuidance.first?.resolution
                == .unresolvedSpokenMandarin
        )
        #expect(await harness.store.appendedEntries().last == entry)
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
