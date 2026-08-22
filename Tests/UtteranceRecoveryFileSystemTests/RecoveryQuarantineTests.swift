import Foundation
import Testing
import UtteranceRecoveryAPI

@Suite struct RecoveryQuarantineTests {
    @Test func corruptAudioMovesToQuarantine() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        _ = try await store.stage(fixture.segment(), for: fixture.sessionID)
        let record = try fixture.pendingRecordDirectory()
        let audio = record.appending(path: "audio.wav")
        try Data("not-a-wave".utf8).write(to: audio, options: .atomic)

        let recovered = try await store.recoverPending(for: fixture.sessionID)

        #expect(recovered.pending.isEmpty)
        #expect(recovered.quarantined.count == 1)
        #expect(recovered.quarantined.first?.reason == .malformedAudio)
        let quarantine = fixture.root
            .appending(path: fixture.sessionID.uuidString.lowercased())
            .appending(path: "quarantine")
        #expect(try FileManager.default.contentsOfDirectory(atPath: quarantine.path).count == 1)
    }

    @Test func malformedMetadataMovesToQuarantine() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        _ = try await store.stage(fixture.segment(), for: fixture.sessionID)
        let metadata = try fixture.pendingRecordDirectory().appending(path: "metadata.json")
        try Data("{".utf8).write(to: metadata, options: .atomic)

        let recovered = try await store.recoverPending(for: fixture.sessionID)

        #expect(recovered.pending.isEmpty)
        #expect(recovered.quarantined.first?.reason == .malformedMetadata)
    }
}
