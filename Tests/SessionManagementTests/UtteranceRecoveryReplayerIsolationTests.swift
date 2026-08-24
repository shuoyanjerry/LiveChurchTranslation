import Foundation
@testable import SessionManagement
import Testing
import TranscriptAPI
import VADAPI

@Suite struct UtteranceRecoveryReplayerIsolationTests {
    @Test func missingSafeOutputRetriesLaterAndRecoveryContinues() async throws {
        let harness = SessionTestHarness(
            recognizedTexts: ["第一句。", "第二句。"],
            translationRejectsFirstOutput: true
        )
        let sessionID = UUID()
        await beginPriorSession(harness, id: sessionID)
        try await stage(harness, sessionID: sessionID, count: 2)
        let replayer = await makeReplayer(harness)

        let firstIssues = await replayer.replay()
        let requestCount = await harness.translator.receivedRequests().count
        let secondIssues = await replayer.replay()

        #expect(requestCount == 2)
        #expect((await harness.translator.receivedRequests()).count == 3)
        #expect(firstIssues.count == 1)
        #expect(firstIssues.first?.isRecoverable == true)
        #expect(secondIssues.isEmpty)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect(Set((await harness.recoveryStore.completedIDs()).map(\.sequenceNumber)) == [1, 2])
        #expect((await harness.recoveryStore.terminalRejections()).isEmpty)
    }

    @Test func runtimeFailureStopsTheEntireRecoveryScanAfterOneAttempt() async throws {
        let harness = SessionTestHarness(translationFails: true)
        let sessionID = UUID()
        await beginPriorSession(harness, id: sessionID)
        try await stage(harness, sessionID: sessionID, count: 40)

        let replayer = await makeReplayer(harness)
        let issues = await replayer.replay()

        #expect((await harness.asr.receivedRequests()).count == 1)
        #expect((await harness.translator.receivedRequests()).count == 1)
        #expect((await harness.recoveryStore.pendingRecords()).count == 40)
        #expect(issues.count == 1)
        #expect(issues.first?.isRecoverable == true)
    }

    @Test func missingTranscriptDoesNotStarveLaterSessions() async throws {
        let harness = SessionTestHarness()
        let missingSessionID = UUID()
        try await stage(harness, sessionID: missingSessionID, count: 2)
        let validSessionID = UUID()
        await beginPriorSession(harness, id: validSessionID)
        try await stage(harness, sessionID: validSessionID, count: 1)

        let issues = await makeReplayer(harness).replay()

        #expect(issues.count == 1)
        #expect((await harness.asr.receivedRequests()).count == 1)
        #expect((await harness.translator.receivedRequests()).count == 1)
        #expect(
            (await harness.recoveryStore.pendingRecords()).allSatisfy {
                $0.id.sessionID == missingSessionID
            }
        )
        #expect(
            (await harness.recoveryStore.completedIDs()).contains {
                $0.sessionID == validSessionID
            }
        )
    }

    @Test func reviewedRecoveryPersistsButNeverFeedsLaterTranslationContext() async throws {
        let harness = SessionTestHarness(
            recognizedTexts: ["第一句。", "第二句。"],
            translationReviewedRequestIndices: [0]
        )
        let sessionID = UUID()
        await beginPriorSession(harness, id: sessionID)
        try await stage(harness, sessionID: sessionID, count: 2)

        let issues = await makeReplayer(harness).replay()

        #expect(issues.isEmpty)
        let requests = await harness.translator.receivedRequests()
        #expect(requests.count == 2)
        #expect(requests[1].context.isEmpty)
        let entries = await harness.store.persistedEntries()
        #expect(entries.count == 2)
        #expect(entries[0].translationReview?.issueCodes == ["quality.pronoun_alignment"])
        #expect(entries[1].translationReview == nil)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect(Set((await harness.recoveryStore.completedIDs()).map(\.sequenceNumber)) == [1, 2])
    }

    private func makeReplayer(
        _ harness: SessionTestHarness
    ) async -> UtteranceRecoveryReplayer {
        let dependencies = await harness.coordinator.dependencies
        return UtteranceRecoveryReplayer(
            dependencies: dependencies,
            processor: UtteranceProcessor(dependencies: dependencies),
            excludedSessionID: nil
        )
    }

    private func beginPriorSession(_ harness: SessionTestHarness, id: UUID) async {
        await harness.store.begin(
            TranscriptSession(
                id: id,
                startedAt: Date(timeIntervalSince1970: 1),
                endedAt: nil,
                entries: []
            )
        )
    }

    private func stage(
        _ harness: SessionTestHarness,
        sessionID: UUID,
        count: Int
    ) async throws {
        for sequence in 1...count {
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
