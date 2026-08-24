import Foundation
import PersistenceAPI
import PersistenceFileSystem
import Testing
import TranscriptAPI

@Suite struct PersistenceFileSystemTests {}

extension PersistenceFileSystemTests {
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

    @Test func multiSentenceUnicodeSegmentRoundTripsWithoutSplitting() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        let source = "恩典拯救我们。\n基督说：“你们要祷告。”"
        let target = "Grace saves us.\nChrist said, “You should pray.”"
        let entry = TranscriptEntry(
            sequence: 1,
            sourceSegmentSequence: 9,
            sourceText: source,
            targetText: target,
            startedMilliseconds: 1_250,
            endedMilliseconds: 8_750,
            translationMilliseconds: 640
        )
        try await fixture.store.begin(fixture.session)
        try await fixture.store.append(entry, to: fixture.session.id)
        try await fixture.store.finish(
            TranscriptSession(
                id: fixture.session.id,
                startedAt: fixture.session.startedAt,
                endedAt: Date(),
                entries: [entry]
            )
        )

        let reloaded = try await FileTranscriptStore(root: fixture.root)
            .load(sessionID: fixture.session.id)

        #expect(reloaded?.entries.count == 1)
        #expect(reloaded?.entries.first?.sourceText == source)
        #expect(reloaded?.entries.first?.targetText.isEmpty == true)
        #expect(reloaded?.entries.first?.translationReview == nil)
        #expect(reloaded?.entries.first?.translationMilliseconds == 0)
        #expect(reloaded?.entries.first?.id == entry.id)
    }
}

extension PersistenceFileSystemTests {
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
        let persisted = try #require(
            try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        )
        #expect(persisted["rawSourceText"] as? String == "嗯典")
        #expect((persisted["sourceCorrections"] as? [[String: Any]])?.count == 1)
        #expect(persisted["targetText"] == nil)
        #expect(persisted["translationReview"] == nil)
        #expect(persisted["translationMilliseconds"] == nil)
        let markdown = try String(contentsOf: fixture.markdownURL, encoding: .utf8)
        #expect(!markdown.contains("grace"))
        #expect(markdown.components(separatedBy: "## 片段 1 · 00:00:00.000–00:00:01.000").count == 2)
        #expect(!markdown.contains("**译文**"))
        #expect(markdown.contains("**识别文字**\n\n恩典"))
        #expect(markdown.contains("- 识别语言：简体中文"))
        #expect(!markdown.contains("翻译方向"))
        #expect(markdown.contains("- 结束时间："))
        #expect(markdown.contains("- 记录状态：完整"))
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
