import Foundation
import PersistenceFileSystem
import Testing
import TranscriptAPI

@Suite struct TranscriptMarkdownTests {
    @Test func importedAudioIncludesAvailableSessionMetadata() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        let startedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let endedAt = startedAt.addingTimeInterval(90)
        let entry = importedEntry()
        let session = importedSession(id: fixture.session.id, startedAt: startedAt)
        let store = FileTranscriptStore(root: fixture.root)
        try await store.begin(session)
        let activeMarkdown = try String(contentsOf: fixture.markdownURL, encoding: .utf8)
        expectActiveImportedMarkdown(activeMarkdown)

        try await store.finish(finishedSession(session, entry: entry, endedAt: endedAt))

        let markdown = try String(contentsOf: fixture.markdownURL, encoding: .utf8)
        expectFinishedImportedMarkdown(markdown)
    }

    @Test func untrustedTextCannotCreateMarkdownStructure() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        let entry = untrustedEntry()
        let session = untrustedSession(id: fixture.session.id)
        let store = FileTranscriptStore(root: fixture.root)
        try await store.begin(session)
        try await store.finish(finishedSession(session, entry: entry))

        let markdown = try String(contentsOf: fixture.markdownURL, encoding: .utf8)
        expectUntrustedTextEscaped(markdown)
    }

    private func expectActiveImportedMarkdown(_ markdown: String) {
        #expect(markdown.contains("# 导入媒体听抄稿"))
        #expect(markdown.contains("- 结束时间：进行中"))
        #expect(markdown.contains("- 记录状态：处理中"))
    }

    private func expectFinishedImportedMarkdown(_ markdown: String) {
        #expect(markdown.contains("- 标题：Sunday message\\.mp3"))
        #expect(markdown.contains("- 识别语言：英文"))
        #expect(!markdown.contains("翻译方向"))
        #expect(markdown.contains("- 开始时间："))
        #expect(!markdown.contains("- 结束时间：进行中"))
        #expect(markdown.contains("## 片段 7 · 01:01:01.004–01:01:03.250"))
        #expect(markdown.contains("**识别文字**\n\nThe Lord is my shepherd\\."))
        #expect(!markdown.contains("耶和华是我的牧者"))
        #expect(!markdown.contains("**译文**"))
        #expect(markdown.contains("## 记录状态\n\n会议记录完整。"))
    }

    private func expectUntrustedTextEscaped(_ markdown: String) {
        let lines = markdown.components(separatedBy: .newlines)
        #expect(markdown.contains("- 标题：\\# forged title \\> forged subtitle"))
        #expect(markdown.contains("\\# forged heading"))
        #expect(markdown.contains("\\> forged quote"))
        #expect(markdown.contains("\\`\\`\\`"))
        #expect(markdown.contains("&lt;div\\>"))
        #expect(!markdown.contains("forged translation"))
        #expect(!markdown.contains("https://example\\.com"))
        #expect(!markdown.contains("emphasis"))
        #expect(!lines.contains("# forged heading"))
        #expect(!lines.contains("> forged quote"))
        #expect(!lines.contains("```"))
        #expect(!lines.contains("- forged list"))
        #expect(!markdown.contains("<div>"))
    }

    private func importedEntry() -> TranscriptEntry {
        TranscriptEntry(
            sequence: 7,
            sourceText: "The Lord is my shepherd.",
            targetText: "耶和华是我的牧者。",
            startedMilliseconds: 3_661_004,
            endedMilliseconds: 3_663_250,
            translationMilliseconds: 20
        )
    }

    private func importedSession(id: UUID, startedAt: Date) -> TranscriptSession {
        TranscriptSession(
            id: id,
            startedAt: startedAt,
            endedAt: nil,
            entries: [],
            title: "Sunday message.mp3",
            kind: .importedAudio,
            sourceLanguage: "en-US",
            targetLanguage: "zh-Hans"
        )
    }

    private func untrustedEntry() -> TranscriptEntry {
        TranscriptEntry(
            sequence: 1,
            sourceText: "# forged heading\n> forged quote\n```\n- forged list\n<div>",
            targetText: "## forged translation\n```swift\n[link](https://example.com)\n_emphasis_\n```",
            startedMilliseconds: 0,
            endedMilliseconds: 1_000,
            translationMilliseconds: 20
        )
    }

    private func untrustedSession(id: UUID) -> TranscriptSession {
        TranscriptSession(
            id: id,
            startedAt: Date(timeIntervalSince1970: 1_750_000_000),
            endedAt: nil,
            entries: [],
            title: "# forged title\n> forged subtitle",
            kind: .importedAudio,
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )
    }

    private func finishedSession(
        _ session: TranscriptSession,
        entry: TranscriptEntry,
        endedAt: Date? = nil
    ) -> TranscriptSession {
        TranscriptSession(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: endedAt ?? session.startedAt.addingTimeInterval(1),
            entries: [entry],
            title: session.title,
            kind: session.kind,
            sourceLanguage: session.sourceLanguage,
            targetLanguage: session.targetLanguage
        )
    }
}
