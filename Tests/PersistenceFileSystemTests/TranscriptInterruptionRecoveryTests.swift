import Foundation
import PersistenceAPI
import PersistenceFileSystem
import Testing
import TranscriptAPI

@Suite struct TranscriptInterruptionRecoveryTests {
    @Test func rebuildsInterruptedManifestFromJSONLinesWithoutPendingRecords() async throws {
        let fixture = TranscriptRecoveryFixture()
        defer { fixture.remove() }
        let writer = FileTranscriptStore(root: fixture.root)
        try await writer.begin(fixture.session)
        try await writer.append(fixture.entry(sequence: 1), to: fixture.session.id)
        try await writer.append(fixture.entry(sequence: 2), to: fixture.session.id)
        var legacyManifest = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: fixture.manifestURL))
                as? [String: Any]
        )
        legacyManifest.removeValue(forKey: "integrity")
        try JSONSerialization.data(withJSONObject: legacyManifest, options: [.sortedKeys]).write(
            to: fixture.manifestURL,
            options: .atomic
        )

        let restarted = FileTranscriptStore(root: fixture.root)
        let scan = await restarted.interruptedSessions(maximumCount: 10)
        #expect(
            scan.candidates == [
                TranscriptRecoveryCandidate(
                    sessionID: fixture.session.id,
                    requiresTranscriptRecovery: true,
                    hasRecordingActivityArtifact: false
                )
            ]
        )

        let result = try await restarted.recoverInterruptedSession(
            sessionID: fixture.session.id
        )
        guard case .recovered(let recovered) = result else {
            Issue.record("Expected the interrupted transcript to be recovered")
            return
        }
        #expect(recovered.entryCount == 2)
        #expect(recovered.endedAt >= fixture.session.startedAt)

        let summary = try #require(try await restarted.recentSessions(limit: 1).first)
        #expect(summary.endedAt == recovered.endedAt)
        #expect(summary.entryCount == 2)
        #expect(summary.integrity == .recoveredAfterInterruption)
        let loaded = try #require(try await restarted.load(sessionID: fixture.session.id))
        #expect(loaded.entries.map(\.sequence) == [1, 2])
        #expect(loaded.endedAt == recovered.endedAt)

        let recoveredManifest = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: fixture.manifestURL))
                as? [String: Any]
        )
        #expect(recoveredManifest["entryCount"] as? Int == 2)
        #expect(
            recoveredManifest["integrity"] as? String
                == StoredTranscriptIntegrity.recoveredAfterInterruption.rawValue
        )
        let markdown = try String(contentsOf: fixture.markdownURL, encoding: .utf8)
        #expect(markdown.contains("\n---\n"))
        #expect(markdown.contains("中断后恢复"))
        #expect(!markdown.contains("会议记录完整"))
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

    @Test func corruptManifestRemainsARecoveryCandidateAfterCAFMarkerClears() async throws {
        let fixture = TranscriptRecoveryFixture()
        defer { fixture.remove() }
        let writer = FileTranscriptStore(root: fixture.root)
        try await writer.begin(fixture.session)
        try Data("corrupt-manifest".utf8).write(to: fixture.manifestURL, options: .atomic)
        let recordingMarker = fixture.sessionDirectory.appending(path: ".recording-active")
        try Data().write(to: recordingMarker, options: .withoutOverwriting)

        let restarted = FileTranscriptStore(root: fixture.root)
        let beforeCAFRepair = await restarted.interruptedSessions(maximumCount: 10)
        #expect(beforeCAFRepair.issues.map(\.code) == [.manifestInspectionFailed])
        #expect(beforeCAFRepair.candidates.first?.requiresTranscriptRecovery == true)
        #expect(beforeCAFRepair.candidates.first?.hasRecordingActivityArtifact == true)

        try FileManager.default.removeItem(at: recordingMarker)
        let afterCAFRepair = await restarted.interruptedSessions(maximumCount: 10)
        #expect(afterCAFRepair.issues.map(\.code) == [.manifestInspectionFailed])
        #expect(afterCAFRepair.candidates.first?.requiresTranscriptRecovery == true)
        #expect(afterCAFRepair.candidates.first?.hasRecordingActivityArtifact == false)
    }
}

private struct TranscriptRecoveryFixture {
    let root = FileManager.default.temporaryDirectory.appending(
        path: UUID().uuidString,
        directoryHint: .isDirectory
    )
    let session = TranscriptSession(
        id: UUID(),
        startedAt: Date(timeIntervalSince1970: 1_750_000_000),
        endedAt: nil,
        entries: []
    )

    var sessionDirectory: URL { root.appending(path: session.id.uuidString) }
    var manifestURL: URL { sessionDirectory.appending(path: "session.json") }
    var jsonLinesURL: URL { sessionDirectory.appending(path: "transcript.jsonl") }
    var markdownURL: URL { sessionDirectory.appending(path: "transcript.md") }

    func entry(sequence: Int) -> TranscriptEntry {
        TranscriptEntry(
            sequence: sequence,
            sourceText: "恩典 \(sequence)",
            targetText: "grace \(sequence)",
            startedMilliseconds: Int64((sequence - 1) * 1_000),
            endedMilliseconds: Int64(sequence * 1_000),
            translationMilliseconds: 10,
            createdAt: session.startedAt.addingTimeInterval(Double(sequence))
        )
    }

    func remove() {
        do {
            if FileManager.default.fileExists(atPath: root.path) {
                try FileManager.default.removeItem(at: root)
            }
        } catch {
            Issue.record("Could not remove transcript recovery fixture: \(error)")
        }
    }
}
