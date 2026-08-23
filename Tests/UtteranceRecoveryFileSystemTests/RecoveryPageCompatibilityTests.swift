import Foundation
import Testing
import UtteranceRecoveryAPI
import VADAPI

@Suite struct RecoveryPageCompatibilityTests {
    @Test func legacyStoreReceivesDefaultPagedMigrationBridge() async throws {
        let sessionID = UUID()
        let segment = SpeechSegment(
            sequenceNumber: 1,
            samples: [0.25],
            sampleRate: 16_000,
            startedAt: .zero,
            endedAt: .milliseconds(20),
            endReason: .trailingSilence
        )
        let record = PendingUtteranceRecord(
            id: PendingUtteranceID(
                sessionID: sessionID,
                segmentID: segment.id,
                sequenceNumber: segment.sequenceNumber
            ),
            segment: segment,
            stagedAt: Date(timeIntervalSince1970: 1)
        )
        let store = LegacyOnlyRecoveryStore(record: record)

        let pages = try await store.recoverAllPendingPages(maximumRecordsPerPage: 1)
        var recovered: [PendingUtteranceRecord] = []
        for try await page in pages { recovered += page.pending }

        #expect(recovered == [record])
        #expect(await store.legacyRecoveryCalls() == 1)
    }
}

private actor LegacyOnlyRecoveryStore: UtteranceRecoveryStore {
    let record: PendingUtteranceRecord
    var recoveryCalls = 0

    init(record: PendingUtteranceRecord) {
        self.record = record
    }

    func stage(
        _: SpeechSegment,
        for _: UUID
    ) throws -> PendingUtteranceRecord {
        throw UtteranceRecoveryError.invalidConfiguration("test")
    }

    func recoverPending(for _: UUID) -> UtteranceRecoveryBatch {
        UtteranceRecoveryBatch(pending: [record], quarantined: [])
    }

    func recoverAllPending() -> UtteranceRecoveryBatch {
        recoveryCalls += 1
        return UtteranceRecoveryBatch(pending: [record], quarantined: [])
    }

    func summary(for _: UUID) -> UtteranceRecoverySessionSummary {
        UtteranceRecoverySessionSummary(
            pendingRecordCount: 1,
            rejections: [],
            quarantinedArtifactCount: 0
        )
    }

    func resolve(_: PendingUtteranceID, as _: UtteranceRecoveryResolution) {}
    func deleteArtifacts(for _: UUID) {}
    func legacyRecoveryCalls() -> Int { recoveryCalls }
}
