import Foundation
import Testing
import UtteranceRecoveryAPI
import UtteranceRecoveryFileSystem

@Suite struct RecoveryAllSessionsTests {
    @Test func restartRecoversEveryPriorSessionInDeterministicOrder() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let firstSession = UUID()
        let secondSession = UUID()
        let lateStore = try FileUtteranceRecoveryStore(
            root: fixture.root,
            now: { fixture.stagedAt.addingTimeInterval(10) }
        )
        _ = try await lateStore.stage(fixture.segment(sequence: 1), for: firstSession)
        let earlyStore = try FileUtteranceRecoveryStore(
            root: fixture.root,
            now: { fixture.stagedAt }
        )
        _ = try await earlyStore.stage(fixture.segment(sequence: 4), for: secondSession)

        let restartedStore = try FileUtteranceRecoveryStore(root: fixture.root)
        let recovered = try await restartedStore.recoverAllPending()

        #expect(recovered.pending.map(\.id.sessionID) == [secondSession, firstSession])
        #expect(recovered.pending.map(\.id.sequenceNumber) == [4, 1])
        #expect(recovered.quarantined.isEmpty)
    }

    @Test func nonSessionRootArtifactsAndSymlinksAreQuarantined() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let external = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: external) }
        try Data("unexpected".utf8).write(to: fixture.root.appending(path: "junk"))
        try FileManager.default.createSymbolicLink(
            at: fixture.root.appending(path: UUID().uuidString.lowercased()),
            withDestinationURL: external
        )
        let store = try fixture.store()

        let recovered = try await store.recoverAllPending()

        #expect(recovered.pending.isEmpty)
        #expect(recovered.quarantined.count == 2)
        #expect(recovered.quarantined.allSatisfy { $0.sessionID == nil })
        #expect(FileManager.default.fileExists(atPath: external.path))
    }

    @Test func rootEnumerationStopsAtConfiguredLimit() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        for _ in 0..<3 {
            try FileManager.default.createDirectory(
                at: fixture.root.appending(path: UUID().uuidString.lowercased()),
                withIntermediateDirectories: false
            )
        }
        let limits = UtteranceRecoveryLimits(
            maximumSampleCount: 10,
            maximumWAVFileBytes: 1_000,
            maximumRootEntryCount: 3,
            maximumSessionCount: 3
        )
        let store = try fixture.store(limits: limits)

        await #expect(throws: UtteranceRecoveryError.rootEntryCountExceeded(maximum: 3)) {
            try await store.recoverAllPending()
        }
    }
}
