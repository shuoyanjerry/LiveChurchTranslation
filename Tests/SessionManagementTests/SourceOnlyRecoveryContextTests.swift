import Foundation
@testable import SessionManagement
import Testing
import TranscriptAPI
import VADAPI

@Suite struct SourceOnlyRecoveryContextTests {
    @Test func archivedEntryNeverCreatesBlankTranslationContext() async throws {
        let harness = SessionTestHarness(recognizedTexts: ["第二段。", "第三段。"])
        let sessionID = UUID()
        await stageArchivedEntry(harness, sessionID: sessionID)
        try await stagePendingSegments(harness, sessionID: sessionID)
        let dependencies = await harness.coordinator.dependencies

        let issues = await UtteranceRecoveryReplayer(
            dependencies: dependencies,
            processor: UtteranceProcessor(dependencies: dependencies),
            excludedSessionID: nil
        ).replay()

        #expect(issues.isEmpty)
        let requests = await harness.translator.receivedRequests()
        #expect(requests.count == 2)
        #expect(requests[0].context.isEmpty)
        #expect(requests[1].context.map(\.sourceText) == ["第二段。"])
    }

    private func stageArchivedEntry(_ harness: SessionTestHarness, sessionID: UUID) async {
        await harness.store.begin(
            TranscriptSession(
                id: sessionID,
                startedAt: Date(timeIntervalSince1970: 1),
                endedAt: nil,
                entries: []
            )
        )
        await harness.store.seed(
            TranscriptEntry(
                sequence: 1,
                sourceSegmentSequence: 1,
                sourceText: "第一段。",
                targetText: "",
                startedMilliseconds: 0,
                endedMilliseconds: 20,
                translationMilliseconds: 0
            )
        )
    }

    private func stagePendingSegments(
        _ harness: SessionTestHarness,
        sessionID: UUID
    ) async throws {
        for sequence in 2...3 {
            _ = try await harness.recoveryStore.stage(
                SpeechSegment(
                    sequenceNumber: UInt64(sequence),
                    samples: SessionTestHarness.audioFrame.samples,
                    sampleRate: 16_000,
                    startedAt: .milliseconds(Int64((sequence - 1) * 20)),
                    endedAt: .milliseconds(Int64(sequence * 20)),
                    endReason: .trailingSilence
                ),
                for: sessionID
            )
        }
    }
}
