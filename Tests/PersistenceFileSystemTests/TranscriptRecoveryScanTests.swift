import Foundation
import PersistenceAPI
import PersistenceFileSystem
import Testing
import TranscriptAPI

@Suite struct TranscriptRecoveryScanTests {
    @Test func traversalAndCandidateWorkStayWithinConfiguredBounds() async throws {
        let fixture = TranscriptRecoveryFixture()
        defer { fixture.remove() }
        let writer = FileTranscriptStore(root: fixture.root)
        for offset in 0..<3 {
            let session = TranscriptSession(
                id: UUID(),
                startedAt: fixture.session.startedAt.addingTimeInterval(Double(offset)),
                endedAt: nil,
                entries: []
            )
            try await writer.begin(session)
        }

        let restarted = FileTranscriptStore(
            root: fixture.root,
            recoveryLimits: TranscriptRecoveryLimits(
                maximumDirectoryEntries: 1,
                maximumCandidateSessions: 1,
                maximumTranscriptBytes: 1_024,
                maximumEntriesPerSession: 10
            )
        )
        let scan = await restarted.interruptedSessions(maximumCount: 10)

        #expect(scan.candidates.count == 1)
        #expect(scan.didReachLimit)
    }

    @Test func corruptManifestRemainsARecoveryCandidateAfterCAFMarkerClears() async throws {
        let fixture = TranscriptRecoveryFixture()
        defer { fixture.remove() }
        let writer = FileTranscriptStore(root: fixture.root)
        try await writer.begin(fixture.session)
        try Data("corrupt-manifest".utf8).write(to: fixture.manifestURL, options: .atomic)
        let recordingMarker = fixture.sessionDirectory.appending(path: ".recording-active")
        try Data().write(to: recordingMarker, options: .withoutOverwriting)

        let restarted = FileTranscriptStore(root: fixture.root)
        let beforeRepair = await restarted.interruptedSessions(maximumCount: 10)
        #expect(beforeRepair.issues.map(\.code) == [.manifestInspectionFailed])
        #expect(beforeRepair.candidates.first?.requiresTranscriptRecovery == true)
        #expect(beforeRepair.candidates.first?.hasRecordingActivityArtifact == true)

        try FileManager.default.removeItem(at: recordingMarker)
        let afterRepair = await restarted.interruptedSessions(maximumCount: 10)
        #expect(afterRepair.issues.map(\.code) == [.manifestInspectionFailed])
        #expect(afterRepair.candidates.first?.requiresTranscriptRecovery == true)
        #expect(afterRepair.candidates.first?.hasRecordingActivityArtifact == false)
    }
}
