import Foundation
import PersistenceFileSystem
import Testing
import TranscriptAPI

@Suite struct PersistenceFileSystemTests {
    @Test func sessionWritesMarkdownAndJSONLines() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        try await fixture.store.begin(fixture.session)
        try await fixture.store.append(fixture.entry, to: fixture.session.id)
        try await fixture.store.append(fixture.entry, to: fixture.session.id)
        try await fixture.store.finish(
            TranscriptSession(
                id: fixture.session.id,
                startedAt: fixture.session.startedAt,
                endedAt: Date(),
                entries: [fixture.entry]
            )
        )
        let summaries = try await fixture.store.recentSessions(limit: 5)
        #expect(summaries.first?.id == fixture.session.id)
        try assertPersistedFiles(fixture)
    }

    private func assertPersistedFiles(_ fixture: PersistenceFixture) throws {
        let contents = try String(contentsOf: fixture.jsonLinesURL, encoding: .utf8)
        let lines = contents.split(whereSeparator: \Character.isNewline)
        let line = try #require(lines.first.map(String.init))
        #expect(lines.count == 1)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let persisted = try decoder.decode(TranscriptEntry.self, from: Data(line.utf8))
        #expect(persisted.rawSourceText == "嗯典")
        #expect(persisted.sourceCorrections.count == 1)
        let markdown = try String(contentsOf: fixture.markdownURL, encoding: .utf8)
        #expect(markdown.contains("grace"))
        #expect(markdown.components(separatedBy: "## 1").count == 2)
    }
}

private struct PersistenceFixture {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let session = TranscriptSession(id: UUID(), startedAt: Date(), endedAt: nil, entries: [])
    let entry = TranscriptEntry(
        sequence: 1,
        rawSourceText: "嗯典",
        sourceText: "恩典",
        sourceCorrections: [
            TranscriptSourceCorrection(observedText: "嗯典", replacementText: "恩典")
        ],
        targetText: "grace",
        startedMilliseconds: 0,
        endedMilliseconds: 1_000,
        translationMilliseconds: 20
    )

    var store: FileTranscriptStore { FileTranscriptStore(root: root) }
    var sessionDirectory: URL { root.appending(path: session.id.uuidString) }
    var jsonLinesURL: URL { sessionDirectory.appending(path: "transcript.jsonl") }
    var markdownURL: URL { sessionDirectory.appending(path: "transcript.md") }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
