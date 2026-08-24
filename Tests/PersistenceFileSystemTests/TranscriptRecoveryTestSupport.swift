import Foundation
import PersistenceAPI
import PersistenceFileSystem
import Testing
import TranscriptAPI

struct TranscriptRecoveryFixture {
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
    var recoveryCandidate: TranscriptRecoveryCandidate {
        TranscriptRecoveryCandidate(
            sessionID: session.id,
            requiresTranscriptRecovery: true,
            hasRecordingActivityArtifact: false
        )
    }

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

    func stageLegacyInterruptedTranscript() async throws {
        let writer = FileTranscriptStore(root: root)
        try await writer.begin(session)
        try await writer.append(entry(sequence: 1), to: session.id)
        try await writer.append(entry(sequence: 2), to: session.id)
        var manifest = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL))
                as? [String: Any]
        )
        manifest.removeValue(forKey: "integrity")
        try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys]).write(
            to: manifestURL,
            options: .atomic
        )
    }

    func stagePartiallyMigratedInterruptedTranscript() async throws {
        try await stageLegacyInterruptedTranscript()
        var manifest = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL))
                as? [String: Any]
        )
        manifest.removeValue(forKey: "schemaVersion")
        manifest.removeValue(forKey: "contentPolicy")
        try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys]).write(
            to: manifestURL,
            options: .atomic
        )
    }

    func assertRecoveredState(
        _ recovered: RecoveredTranscriptSession,
        in store: FileTranscriptStore
    ) async throws {
        let summary = try #require(try await store.recentSessions(limit: 1).first)
        #expect(summary.endedAt == recovered.endedAt)
        #expect(summary.entryCount == 2)
        #expect(summary.integrity == .recoveredAfterInterruption)
        let loaded = try #require(try await store.load(sessionID: session.id))
        #expect(loaded.entries.map(\.sequence) == [1, 2])
        #expect(loaded.endedAt == recovered.endedAt)
    }

    func assertRecoveredArtifacts() throws {
        let manifest = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL))
                as? [String: Any]
        )
        #expect(manifest["entryCount"] as? Int == 2)
        #expect(
            manifest["integrity"] as? String
                == StoredTranscriptIntegrity.recoveredAfterInterruption.rawValue
        )
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        #expect(markdown.contains("\n---\n"))
        #expect(markdown.contains("中断后恢复"))
        #expect(!markdown.contains("会议记录完整"))
        let transcript = try Data(contentsOf: jsonLinesURL)
        let lines = transcript.split(separator: 0x0A)
        #expect(lines.count == 2)
        for line in lines {
            let object = try #require(
                try JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
            )
            #expect(object["targetText"] == nil)
            #expect(object["translationReview"] == nil)
            #expect(object["translationMilliseconds"] == nil)
        }
        let transcriptText = try #require(String(data: transcript, encoding: .utf8))
        #expect(!transcriptText.contains("grace"))
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
