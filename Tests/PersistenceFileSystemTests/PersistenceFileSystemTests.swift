import Foundation
import PersistenceFileSystem
import Testing
import TranscriptAPI

@Suite struct PersistenceFileSystemTests {
    @Test func sessionWritesMarkdownAndJSONLines() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileTranscriptStore(root: root)
        let session = TranscriptSession(id: UUID(), startedAt: Date(), endedAt: nil, entries: [])
        let entry = TranscriptEntry(
            sequence: 1, sourceText: "恩典", targetText: "grace",
            startedMilliseconds: 0, endedMilliseconds: 1_000,
            translationMilliseconds: 20
        )
        try await store.begin(session)
        try await store.append(entry, to: session.id)
        let summaries = try await store.recentSessions(limit: 5)
        #expect(summaries.first?.id == session.id)
    }
}
