import Foundation
import Testing
import UtteranceRecoveryAPI
import UtteranceRecoveryFileSystem

@Suite struct RecoveryResolutionLifecycleTests {
    @Test func terminalRejectionLeavesReceiptButNeverReentersRetryQueue() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        let staged = try await store.stage(fixture.segment(), for: fixture.sessionID)
        let receipt = rejectionReceipt(for: staged.id)
        try await store.resolve(staged.id, as: .terminallyRejected([receipt]))

        let restartedStore = try fixture.store()
        let recovered = try await restartedStore.recoverPending(for: fixture.sessionID)
        #expect(recovered.pending.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: activeSessionPath(fixture).path))
        let stored = try storedRejection(fixture: fixture)
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
        #expect(!FileManager.default.fileExists(atPath: activeSessionPath(fixture).path))
        #expect(!FileManager.default.fileExists(atPath: rejectedSessionPath(fixture).path))
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

    private func storedRejection(
        fixture: RecoveryTestFixture
    ) throws -> TerminalUtteranceRejectionRecord {
        let records = try FileManager.default.contentsOfDirectory(
            at: rejectedSessionPath(fixture),
            includingPropertiesForKeys: nil
        )
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(!FileManager.default.fileExists(atPath: record.appending(path: "audio.wav").path))
        let data = try Data(contentsOf: record.appending(path: "rejection.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TerminalUtteranceRejectionRecord.self, from: data)
    }

    private func rejectedRecordCount(fixture: RecoveryTestFixture) throws -> Int {
        try FileManager.default.contentsOfDirectory(
            at: rejectedSessionPath(fixture),
            includingPropertiesForKeys: nil
        ).count
    }

    private func activeSessionPath(_ fixture: RecoveryTestFixture) -> URL {
        fixture.root.appending(path: fixture.sessionID.uuidString.lowercased())
    }

    private func rejectedSessionPath(_ fixture: RecoveryTestFixture) -> URL {
        fixture.root.appending(path: ".resolved")
            .appending(path: fixture.sessionID.uuidString.lowercased())
    }
}
