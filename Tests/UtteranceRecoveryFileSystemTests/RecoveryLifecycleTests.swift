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

}
