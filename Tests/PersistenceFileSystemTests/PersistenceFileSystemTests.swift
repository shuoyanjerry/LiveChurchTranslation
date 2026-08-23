import Foundation
import PersistenceAPI
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
        let restarted = FileTranscriptStore(root: fixture.root)
        let reloaded = try await restarted.load(sessionID: fixture.session.id)
        #expect(reloaded?.entries.first?.sourceSegmentSequence == 3)
    }

    @Test func preservesLanguageMetadataAndDeletesTheWholeSession() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        let store = FileTranscriptStore(root: fixture.root)
        let session = TranscriptSession(
            id: fixture.session.id,
            startedAt: fixture.session.startedAt,
            endedAt: nil,
            entries: [],
            title: "Sunday message.mp3",
            kind: .importedAudio,
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )
        try await store.begin(session)

        let summary = try #require(try await store.recentSessions(limit: 1).first)
        #expect(summary.title == "Sunday message.mp3")
        #expect(summary.kind == .importedAudio)
        #expect(summary.sourceLanguage == "en")
        #expect(summary.targetLanguage == "zh-Hans")

        #expect(await store.isSessionActive(sessionID: session.id))
        await #expect(throws: TranscriptStoreError.self) {
            try await store.delete(sessionID: session.id)
        }
        try await store.finish(finishedSession(from: session))
        try await store.delete(sessionID: session.id)
        #expect(!FileManager.default.fileExists(atPath: fixture.sessionDirectory.path))
    }

    @Test func recordingMarkerAndPartialBlockDeletionAcrossStoreInstances() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        let writer = FileTranscriptStore(root: fixture.root)
        try await writer.begin(fixture.session)
        try await writer.finish(
            TranscriptSession(
                id: fixture.session.id,
                startedAt: fixture.session.startedAt,
                endedAt: Date(),
                entries: []
            )
        )
        let marker = fixture.sessionDirectory.appending(path: ".recording-active")
        try Data().write(to: marker, options: .withoutOverwriting)
        let independentReader = FileTranscriptStore(root: fixture.root)

        #expect(await independentReader.isSessionActive(sessionID: fixture.session.id))
        await #expect(throws: TranscriptStoreError.self) {
            try await independentReader.delete(sessionID: fixture.session.id)
        }

        try FileManager.default.removeItem(at: marker)
        let partial = fixture.sessionDirectory.appending(path: "recording.partial.caf")
        try Data([0]).write(to: partial, options: .withoutOverwriting)
        #expect(await independentReader.isSessionActive(sessionID: fixture.session.id))
        await #expect(throws: TranscriptStoreError.self) {
            try await independentReader.delete(sessionID: fixture.session.id)
        }

        try FileManager.default.removeItem(at: partial)
        try await independentReader.delete(sessionID: fixture.session.id)
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

    private func finishedSession(from session: TranscriptSession) -> TranscriptSession {
        TranscriptSession(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: Date(),
            entries: [],
            title: session.title,
            kind: session.kind,
            sourceLanguage: session.sourceLanguage,
            targetLanguage: session.targetLanguage
        )
    }
}

private struct PersistenceFixture {
    let root = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let session = TranscriptSession(id: UUID(), startedAt: Date(), endedAt: nil, entries: [])
    let entry = TranscriptEntry(
        sequence: 1,
        sourceSegmentSequence: 3,
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
