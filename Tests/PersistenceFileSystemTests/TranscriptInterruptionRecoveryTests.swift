import Foundation
import PersistenceAPI
import PersistenceFileSystem
import Testing
import TranscriptAPI

@Suite struct TranscriptInterruptionRecoveryTests {
    @Test func rebuildsInterruptedManifestFromJSONLinesWithoutPendingRecords() async throws {
        let fixture = TranscriptRecoveryFixture()
        defer { fixture.remove() }
        try await fixture.stageLegacyInterruptedTranscript()

        let restarted = FileTranscriptStore(root: fixture.root)
        let scan = await restarted.interruptedSessions(maximumCount: 10)
        #expect(scan.candidates == [fixture.recoveryCandidate])

        let result = try await restarted.recoverInterruptedSession(
            sessionID: fixture.session.id
        )
        guard case .recovered(let recovered) = result else {
            Issue.record("Expected the interrupted transcript to be recovered")
            return
        }
        #expect(recovered.entryCount == 2)
        #expect(recovered.endedAt >= fixture.session.startedAt)
        try await fixture.assertRecoveredState(recovered, in: restarted)
        try fixture.assertRecoveredArtifacts()
    }

    @Test func neverClosesTheCurrentActiveSession() async throws {
        let fixture = TranscriptRecoveryFixture()
        defer { fixture.remove() }
        let store = FileTranscriptStore(root: fixture.root)
        try await store.begin(fixture.session)
        try await store.append(fixture.entry(sequence: 1), to: fixture.session.id)

        let scan = await store.interruptedSessions(maximumCount: 10)
        #expect(scan.candidates.isEmpty)
        #expect(
            try await store.recoverInterruptedSession(sessionID: fixture.session.id)
                == .skippedActive
        )
        let summary = try #require(try await store.recentSessions(limit: 1).first)
        #expect(summary.endedAt == nil)
        #expect(summary.entryCount == 0)
        #expect(summary.integrity == .active)
    }

    @Test func malformedJSONLinesFailWithoutCommittingAFalseRecovery() async throws {
        let fixture = TranscriptRecoveryFixture()
        defer { fixture.remove() }
        let writer = FileTranscriptStore(root: fixture.root)
        try await writer.begin(fixture.session)
        let handle = try FileHandle(forWritingTo: fixture.jsonLinesURL)
        try handle.write(contentsOf: Data("not-json\n".utf8))
        try handle.close()

        let restarted = FileTranscriptStore(root: fixture.root)
        await #expect(throws: TranscriptStoreError.self) {
            _ = try await restarted.recoverInterruptedSession(sessionID: fixture.session.id)
        }
        let summary = try #require(try await restarted.recentSessions(limit: 1).first)
        #expect(summary.endedAt == nil)
        #expect(summary.entryCount == 0)
        #expect(summary.integrity == .active)
    }

}
