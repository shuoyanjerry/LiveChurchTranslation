import Foundation
import PersistenceFileSystem
import Testing

@Suite struct SourceOnlyPersistenceTests {
    @Test func appendAndFinishPersistOnlySourceEvidence() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        let entries = try reviewedEntries()
        let store = FileTranscriptStore(root: fixture.root)

        try await store.begin(sourceSession(fixture.session.id))
        try await store.append(entries[0], to: fixture.session.id)
        try assertSourceOnlyJSONLines(
            at: fixture.jsonLinesURL,
            expectedCount: 1,
            forbiddenTexts: forbiddenTexts
        )

        try await store.append(entries[1], to: fixture.session.id)
        try await store.finish(finishedSourceSession(fixture.session.id, entries: entries))
        try assertSourceOnlyJSONLines(
            at: fixture.jsonLinesURL,
            expectedCount: 2,
            forbiddenTexts: forbiddenTexts
        )
        try assertSourceOnlyMarkdown(at: fixture.markdownURL, entries: entries)

        let loaded = try #require(
            try await FileTranscriptStore(root: fixture.root).load(
                sessionID: fixture.session.id
            )
        )
        assertSourceEvidence(entries, survivedIn: loaded.entries)
    }
}
