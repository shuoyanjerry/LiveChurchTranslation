import Foundation
import PersistenceAPI
import PersistenceFileSystem
import Testing

extension SourceOnlyPersistenceTests {
    @Test func legacyBilingualMigrationIsIdempotentAndPreservesNonTranslationData() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        let legacy = try await stageLegacyBilingualSession(in: fixture)
        let legacyManifest = try jsonObject(legacy.manifestData)
        let activityMarker = fixture.sessionDirectory.appending(path: ".recording-active")
        let markerData = Data("recoverable".utf8)
        try markerData.write(to: activityMarker, options: .atomic)
        let store = FileTranscriptStore(root: fixture.root)

        try await store.migrateLegacySessionsToSourceOnly()

        try assertSourceOnlyJSONLines(
            at: fixture.jsonLinesURL,
            expectedCount: legacy.entries.count,
            forbiddenTexts: forbiddenTexts
        )
        try assertSourceOnlyMarkdown(at: fixture.markdownURL, entries: legacy.entries)
        #expect(try Data(contentsOf: legacy.recordingURL) == legacy.recordingData)
        #expect(try Data(contentsOf: activityMarker) == markerData)
        let migratedManifestData = try Data(contentsOf: legacy.manifestURL)
        let migratedManifest = try jsonObject(migratedManifestData)
        assertManifestMetadataSurvived(from: legacyManifest, to: migratedManifest)

        let loaded = try #require(try await store.load(sessionID: legacy.session.id))
        assertSourceEvidence(legacy.entries, survivedIn: loaded.entries)

        let firstTranscript = try Data(contentsOf: fixture.jsonLinesURL)
        let firstMarkdown = try Data(contentsOf: fixture.markdownURL)
        try await store.migrateLegacySessionsToSourceOnly()
        #expect(try Data(contentsOf: fixture.jsonLinesURL) == firstTranscript)
        #expect(try Data(contentsOf: fixture.markdownURL) == firstMarkdown)
        #expect(try Data(contentsOf: legacy.manifestURL) == migratedManifestData)
        #expect(try Data(contentsOf: legacy.recordingURL) == legacy.recordingData)
        #expect(try Data(contentsOf: activityMarker) == markerData)
    }

    @Test func corruptLegacyTranscriptFailsClosedWithoutPartialCommit() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        let legacy = try await stageLegacyBilingualSession(in: fixture)
        let healthySessions = try stageLegacyEmptySessions(count: 1, root: fixture.root)
        let corruptTranscript = Data("{not-json}\n\(targetSentinel)\n".utf8)
        try corruptTranscript.write(to: fixture.jsonLinesURL, options: .atomic)
        let originalManifest = try Data(contentsOf: legacy.manifestURL)
        let originalMarkdown = try Data(contentsOf: fixture.markdownURL)
        let store = FileTranscriptStore(root: fixture.root)

        await #expect(throws: TranscriptStoreError.self) {
            try await store.migrateLegacySessionsToSourceOnly()
        }
        #expect(try Data(contentsOf: fixture.jsonLinesURL) == corruptTranscript)
        #expect(try Data(contentsOf: legacy.manifestURL) == originalManifest)
        #expect(try Data(contentsOf: fixture.markdownURL) == originalMarkdown)
        #expect(try Data(contentsOf: legacy.recordingURL) == legacy.recordingData)
        try assertAllSessionsMigrated(healthySessions)

        await #expect(throws: TranscriptStoreError.self) {
            _ = try await store.load(sessionID: legacy.session.id)
        }
        await #expect(throws: TranscriptStoreError.self) {
            _ = try await store.recentSessions(limit: 1)
        }
        let unchangedManifest = try jsonObject(Data(contentsOf: legacy.manifestURL))
        #expect(unchangedManifest["schemaVersion"] == nil)
        #expect(unchangedManifest["contentPolicy"] == nil)
    }

    @Test func manifestLastMigrationResumesAfterSourceJSONCommit() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        let legacy = try await stageLegacyBilingualSession(in: fixture)
        let partiallyMigratedJSON = try sourceOnlyProjection(of: legacy.entries)
        try partiallyMigratedJSON.write(to: fixture.jsonLinesURL, options: .atomic)
        let legacyMarkdown = try Data(contentsOf: fixture.markdownURL)
        #expect(try jsonObject(Data(contentsOf: legacy.manifestURL))["schemaVersion"] == nil)

        let store = FileTranscriptStore(root: fixture.root)
        try await store.migrateLegacySessionsToSourceOnly()

        try assertSourceOnlyJSONLines(
            at: fixture.jsonLinesURL,
            expectedCount: legacy.entries.count,
            forbiddenTexts: forbiddenTexts
        )
        #expect(try Data(contentsOf: fixture.markdownURL) != legacyMarkdown)
        try assertSourceOnlyMarkdown(at: fixture.markdownURL, entries: legacy.entries)
        let manifest = try jsonObject(Data(contentsOf: legacy.manifestURL))
        #expect(manifest["schemaVersion"] as? Int == 2)
        #expect(manifest["contentPolicy"] as? String == "sourceOnly")
        #expect(try Data(contentsOf: legacy.recordingURL) == legacy.recordingData)
        let loaded = try #require(try await store.load(sessionID: legacy.session.id))
        assertSourceEvidence(legacy.entries, survivedIn: loaded.entries)
    }

    @Test func migrationCoversMoreThanTheRecoveryCandidatePageLimit() async throws {
        let fixture = PersistenceFixture()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(
            at: fixture.root,
            withIntermediateDirectories: true
        )
        let sessionDirectories = try stageLegacyEmptySessions(count: 2_050, root: fixture.root)

        try await FileTranscriptStore(root: fixture.root).migrateLegacySessionsToSourceOnly()

        try assertAllSessionsMigrated(sessionDirectories)
    }

    private func stageLegacyEmptySessions(count: Int, root: URL) throws -> [URL] {
        try (0..<count).map { _ in
            let id = UUID()
            let directory = root.appending(path: id.uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            try legacyEmptyManifest(id).write(
                to: directory.appending(path: "session.json"),
                atomically: true,
                encoding: .utf8
            )
            try Data().write(
                to: directory.appending(path: "transcript.jsonl"),
                options: .atomic
            )
            try "**译文**\n\n\(targetSentinel)".write(
                to: directory.appending(path: "transcript.md"),
                atomically: true,
                encoding: .utf8
            )
            return directory
        }
    }

    private func legacyEmptyManifest(_ id: UUID) -> String {
        """
        {"id":"\(id.uuidString)","startedAt":"2026-08-24T00:00:00Z","entryCount":0}
        """
    }

    private func assertAllSessionsMigrated(_ directories: [URL]) throws {
        for directory in directories {
            let manifest = try jsonObject(Data(contentsOf: directory.appending(path: "session.json")))
            #expect(manifest["contentPolicy"] as? String == "sourceOnly")
            let markdown = try String(
                contentsOf: directory.appending(path: "transcript.md"),
                encoding: .utf8
            )
            #expect(!markdown.contains(targetSentinel))
        }
    }
}
