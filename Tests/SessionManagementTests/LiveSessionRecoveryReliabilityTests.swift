import Foundation
import Testing
import TranscriptAPI
import VADAPI

@Suite struct LiveSessionRecoveryReliabilityTests {
    @Test func nextStartReplaysCrashStagedAudioBeforeListening() async throws {
        let harness = SessionTestHarness()
        let priorSessionID = UUID()
        await harness.store.begin(
            TranscriptSession(
                id: priorSessionID,
                startedAt: Date(timeIntervalSince1970: 1),
                endedAt: nil,
                entries: []
            )
        )
        let segment = SpeechSegment(
            sequenceNumber: 7,
            samples: SessionTestHarness.audioFrame.samples,
            sampleRate: 16_000,
            startedAt: .zero,
            endedAt: .milliseconds(20),
            endReason: .endOfStream
        )
        _ = try await harness.recoveryStore.stage(segment, for: priorSessionID)

        _ = try await harness.run()

        #expect((await harness.translator.receivedRequests()).count == 2)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.recoveryStore.completedIDs()).count == 2)
        #expect((await harness.store.finishedSessions()).contains { $0.id == priorSessionID })
    }

    @Test func recoveryNeverUsesFutureTranscriptAsContext() async throws {
        let harness = SessionTestHarness()
        let priorSessionID = UUID()
        await harness.store.begin(
            TranscriptSession(
                id: priorSessionID,
                startedAt: Date(timeIntervalSince1970: 1),
                endedAt: nil,
                entries: []
            )
        )
        await harness.store.seed(
            TranscriptEntry(
                sequence: 10,
                sourceText: "未来的姐妹会分享。",
                targetText: "A sister will share later.",
                startedMilliseconds: 1_000,
                endedMilliseconds: 2_000,
                translationMilliseconds: 10
            )
        )
        let segment = SpeechSegment(
            sequenceNumber: 7,
            samples: SessionTestHarness.audioFrame.samples,
            sampleRate: 16_000,
            startedAt: .zero,
            endedAt: .milliseconds(20),
            endReason: .endOfStream
        )
        _ = try await harness.recoveryStore.stage(segment, for: priorSessionID)

        _ = try await harness.run()

        let recoveryRequest = try #require(await harness.translator.receivedRequests().first)
        #expect(recoveryRequest.context.isEmpty)
    }
}
