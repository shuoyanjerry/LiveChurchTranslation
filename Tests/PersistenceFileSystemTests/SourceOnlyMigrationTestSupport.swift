import Foundation
import PersistenceAPI
import PersistenceFileSystem
import Testing
import TranscriptAPI

extension SourceOnlyPersistenceTests {
    struct LegacyFixture: Sendable {
        let session: TranscriptSession
        let entries: [TranscriptEntry]
        let manifestURL: URL
        let manifestData: Data
        let recordingURL: URL
        let recordingData: Data
    }

    func stageLegacyBilingualSession(
        in fixture: PersistenceFixture
    ) async throws -> LegacyFixture {
        let entries = try reviewedEntries()
        let session = sourceSession(fixture.session.id)
        let finished = finishedSourceSession(fixture.session.id, entries: entries)
        let writer = FileTranscriptStore(root: fixture.root)
        try await writer.begin(session)
        try await writer.finish(finished, finalization: legacyFinalization(entries[0].id))
        try writeLegacyEntries(entries, to: fixture.jsonLinesURL)
        try writeLegacyMarkdown(entries, to: fixture.markdownURL)
        let (manifestURL, manifestData) = try downgradeManifest(in: fixture)
        let (recordingURL, recordingData) = try writeRecordingFixture(in: fixture)
        return LegacyFixture(
            session: finished,
            entries: entries,
            manifestURL: manifestURL,
            manifestData: manifestData,
            recordingURL: recordingURL,
            recordingData: recordingData
        )
    }

    private func legacyFinalization(_ sentenceID: UUID) -> TranscriptFinalization {
        TranscriptFinalization(
            pendingRecordCount: 3,
            rejections: [
                StoredTranscriptRejection(
                    sentenceID: sentenceID,
                    sentenceOrdinal: 1,
                    stage: "translation",
                    failureCode: "legacy.review"
                )
            ],
            quarantinedArtifactCount: 2,
            hasUnrecoverableFailure: true
        )
    }

    private func writeLegacyEntries(_ entries: [TranscriptEntry], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var legacyLines = Data()
        for entry in entries {
            legacyLines.append(try encoder.encode(entry))
            legacyLines.append(0x0A)
        }
        try legacyLines.write(to: url, options: .atomic)
    }

    private func writeLegacyMarkdown(_ entries: [TranscriptEntry], to url: URL) throws {
        let legacyMarkdown = """
            # 旧版双语记录

            **识别原文**

            \(entries.map(\.sourceText).joined(separator: "\n"))

            **译文**

            \(targetSentinel)
            \(reviewSentinel)
            """
        try legacyMarkdown.write(to: url, atomically: true, encoding: .utf8)
    }

    private func downgradeManifest(in fixture: PersistenceFixture) throws -> (URL, Data) {
        let manifestURL = fixture.sessionDirectory.appending(path: "session.json")
        var manifest = try jsonObject(Data(contentsOf: manifestURL))
        manifest.removeValue(forKey: "schemaVersion")
        manifest.removeValue(forKey: "contentPolicy")
        let manifestData = try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys]
        )
        try manifestData.write(to: manifestURL, options: .atomic)
        return (manifestURL, manifestData)
    }

    private func writeRecordingFixture(in fixture: PersistenceFixture) throws -> (URL, Data) {
        let recordingURL = fixture.sessionDirectory.appending(path: "recording.caf")
        let recordingData = Data([0x63, 0x61, 0x66, 0x66, 0x00, 0xFF, 0x2A, 0x11])
        try recordingData.write(to: recordingURL, options: .atomic)
        return (recordingURL, recordingData)
    }

    func assertManifestMetadataSurvived(
        from legacy: [String: Any],
        to migrated: [String: Any]
    ) {
        #expect(migrated["schemaVersion"] as? Int == 2)
        #expect(migrated["contentPolicy"] as? String == "sourceOnly")
        for key in [
            "id", "startedAt", "endedAt", "entryCount", "title", "kind",
            "sourceLanguage", "targetLanguage", "integrity", "pendingRecordCount",
            "quarantinedArtifactCount", "hasUnrecoverableFailure",
        ] {
            #expect(String(describing: migrated[key]) == String(describing: legacy[key]))
        }
        let legacyRejections = legacy["rejections"] as? [[String: Any]]
        let migratedRejections = migrated["rejections"] as? [[String: Any]]
        #expect(legacyRejections?.count == 1)
        #expect(migratedRejections?.count == 1)
        #expect(
            migratedRejections?.first?["sentenceID"] as? String
                == legacyRejections?.first?["sentenceID"] as? String
        )
        #expect(
            migratedRejections?.first?["failureCode"] as? String
                == legacyRejections?.first?["failureCode"] as? String
        )
    }
}
