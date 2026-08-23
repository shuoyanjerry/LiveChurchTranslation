import Foundation
import PersistenceAPI
import Testing
import TranscriptAPI

@Suite struct PersistenceFinalizationTests {
    @Test func incompleteFinalizationPersistsCountsAndNeverClaimsCompleteness() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        let store = fixture.store
        try await store.begin(fixture.session)
        let rejection = StoredTranscriptRejection(
            sentenceID: UUID(),
            sentenceOrdinal: 0,
            stage: "translation",
            failureCode: "hymt2.invalid_output"
        )

        try await store.finish(
            finishedSession(from: fixture.session),
            finalization: TranscriptFinalization(
                pendingRecordCount: 2,
                rejections: [rejection],
                quarantinedArtifactCount: 1
            )
        )

        let summary = try #require(try await store.recentSessions(limit: 1).first)
        #expect(summary.integrity == .incomplete)
        #expect(summary.pendingRecordCount == 2)
        #expect(summary.rejectedSentenceCount == 1)
        #expect(summary.quarantinedArtifactCount == 1)
        let markdown = try String(contentsOf: fixture.markdownURL, encoding: .utf8)
        #expect(markdown.contains("未完整处理"))
        #expect(!markdown.contains("会议记录完整"))
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
