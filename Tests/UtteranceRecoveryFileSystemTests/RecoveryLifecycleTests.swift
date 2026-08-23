import Foundation
import Testing
import UtteranceRecoveryAPI
import UtteranceRecoveryFileSystem

@Suite struct RecoveryLifecycleTests {
    @Test func committedSegmentReloadsAfterStoreRecreation() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let original = fixture.segment(reason: .maximumDuration)
        let firstStore = try fixture.store()
        let staged = try await firstStore.stage(original, for: fixture.sessionID)

        let restartedStore = try fixture.store()
        let recovered = try await restartedStore.recoverPending(for: fixture.sessionID)

        #expect(recovered.quarantined.isEmpty)
        #expect(recovered.pending.count == 1)
        #expect(recovered.pending.first == staged)
        #expect(recovered.pending.first?.segment == original)
    }

    @Test func recoveryIsSortedBySequenceRegardlessOfStageOrder() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        _ = try await store.stage(fixture.segment(sequence: 9), for: fixture.sessionID)
        _ = try await store.stage(fixture.segment(sequence: 2), for: fixture.sessionID)
        _ = try await store.stage(fixture.segment(sequence: 5), for: fixture.sessionID)

        let recovered = try await store.recoverPending(for: fixture.sessionID)

        #expect(recovered.pending.map(\.id.sequenceNumber) == [2, 5, 9])
    }

    @Test func completionDeletesAudioAndMetadata() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        let staged = try await store.stage(fixture.segment(), for: fixture.sessionID)

        try await store.markCompleted(staged.id)
        let recovered = try await store.recoverPending(for: fixture.sessionID)

        #expect(recovered.pending.isEmpty)
        #expect(recovered.quarantined.isEmpty)
        let session = fixture.root
            .appending(path: fixture.sessionID.uuidString.lowercased())
        #expect(!FileManager.default.fileExists(atPath: session.path))
    }

    @Test func terminalRejectionLeavesReceiptButNeverReentersRetryQueue() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        let staged = try await store.stage(fixture.segment(), for: fixture.sessionID)
        let receipt = UtteranceRejectionReceipt(
            sentenceID: staged.id.segmentID,
            sentenceOrdinal: 0,
            stage: .translation,
            failureCode: "hymt2.invalid_output"
        )

        try await store.resolve(staged.id, as: .terminallyRejected([receipt]))

        let restartedStore = try fixture.store()
        let recovered = try await restartedStore.recoverPending(for: fixture.sessionID)
        #expect(recovered.pending.isEmpty)
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.root
                    .appending(path: fixture.sessionID.uuidString.lowercased()).path
            )
        )
        let rejected = fixture.root
            .appending(path: ".resolved")
            .appending(path: fixture.sessionID.uuidString.lowercased())
        let records = try FileManager.default.contentsOfDirectory(
            at: rejected,
            includingPropertiesForKeys: nil
        )
        #expect(records.count == 1)
        #expect(!FileManager.default.fileExists(atPath: records[0].appending(path: "audio.wav").path))
        let data = try Data(contentsOf: records[0].appending(path: "rejection.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let stored = try decoder.decode(TerminalUtteranceRejectionRecord.self, from: data)
        #expect(stored.id == staged.id)
        #expect(stored.receipts == [receipt])
        let summary = try await restartedStore.summary(for: fixture.sessionID)
        #expect(summary.pendingRecordCount == 0)
        #expect(summary.rejections == [receipt])
    }

    @Test func retryingAnIdenticalTerminalResolutionIsIdempotent() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let firstStore = try fixture.store()
        let staged = try await firstStore.stage(fixture.segment(), for: fixture.sessionID)
        let receipt = rejectionReceipt(for: staged.id)

        try await firstStore.resolve(staged.id, as: .terminallyRejected([receipt]))
        let restartedStore = try fixture.store()
        try await restartedStore.resolve(staged.id, as: .terminallyRejected([receipt]))

        let recovered = try await restartedStore.recoverPending(for: fixture.sessionID)
        #expect(recovered.pending.isEmpty)
        #expect(try rejectedRecordCount(fixture: fixture) == 1)
    }

    private func rejectionReceipt(
        for id: PendingUtteranceID
    ) -> UtteranceRejectionReceipt {
        UtteranceRejectionReceipt(
            sentenceID: id.segmentID,
            sentenceOrdinal: 0,
            stage: .translation,
            failureCode: "hymt2.invalid_output"
        )
    }

    private func rejectedRecordCount(fixture: RecoveryTestFixture) throws -> Int {
        let rejected = fixture.root
            .appending(path: ".resolved")
            .appending(path: fixture.sessionID.uuidString.lowercased())
        return try FileManager.default.contentsOfDirectory(
            at: rejected,
            includingPropertiesForKeys: nil
        ).count
    }

    @Test func deletingSessionArtifactsRemovesPendingAndRejectedEvidence() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        _ = try await store.stage(fixture.segment(sequence: 1), for: fixture.sessionID)
        let rejected = try await store.stage(
            fixture.segment(sequence: 2),
            for: fixture.sessionID
        )
        try await store.resolve(
            rejected.id,
            as: .terminallyRejected([rejectionReceipt(for: rejected.id)])
        )

        try await store.deleteArtifacts(for: fixture.sessionID)

        #expect(try await store.summary(for: fixture.sessionID) == .empty)
        #expect((try await store.recoverAllPending()).pending.isEmpty)
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.root
                    .appending(path: fixture.sessionID.uuidString.lowercased()).path
            )
        )
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.root.appending(path: ".resolved")
                    .appending(path: fixture.sessionID.uuidString.lowercased()).path
            )
        )
    }
}
