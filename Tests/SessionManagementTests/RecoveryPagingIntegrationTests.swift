import Foundation
import Testing
import TranscriptAPI
import VADAPI

@Suite struct RecoveryPagingIntegrationTests {
    @Test func recoveryCrossesPageBoundariesWithoutLosingSessionOrder() async throws {
        let texts = (1...7).map { "第\($0)句因信称义。" }
        let harness = SessionTestHarness(recognizedTexts: texts)
        let priorSessionID = UUID()
        await harness.store.begin(
            TranscriptSession(
                id: priorSessionID,
                startedAt: Date(timeIntervalSince1970: 1),
                endedAt: nil,
                entries: []
            )
        )
        for sequence in 1...6 {
            _ = try await harness.recoveryStore.stage(
                SpeechSegment(
                    sequenceNumber: UInt64(sequence),
                    samples: SessionTestHarness.audioFrame.samples,
                    sampleRate: 16_000,
                    startedAt: .milliseconds(Int64((sequence - 1) * 20)),
                    endedAt: .milliseconds(Int64(sequence * 20)),
                    endReason: .trailingSilence
                ),
                for: priorSessionID
            )
        }

        _ = try await harness.run()

        let requests = await harness.asr.receivedRequests()
        #expect(requests.prefix(6).map(\.segment.sequenceNumber) == [1, 2, 3, 4, 5, 6])
        #expect(await harness.recoveryStore.recoveryPageSizes() == [4])
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect(
            (await harness.store.finishedSessions()).filter { $0.id == priorSessionID }.count == 1
        )
    }
}
