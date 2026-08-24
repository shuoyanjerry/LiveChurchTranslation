import Foundation
import PersistenceAPI
import TranscriptAPI

extension FileTranscriptStore {
    func append(_ data: Data, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    func writeEntries(_ entries: [TranscriptEntry], sessionID: UUID) throws {
        let encoder = lineEncoder()
        var payload = Data()
        for entry in entries {
            payload.append(try encoder.encode(StoredSourceTranscriptEntry(entry)))
            payload.append(0x0A)
        }
        try payload.write(to: jsonLinesURL(sessionID), options: .atomic)
        try setPrivateFilePermission(jsonLinesURL(sessionID))
        entryIDs[sessionID] = Set(entries.map(\.id))
    }

    func writeMarkdown(_ contents: String, sessionID: UUID) throws {
        try contents.write(
            to: markdownURL(sessionID),
            atomically: true,
            encoding: .utf8
        )
        try setPrivateFilePermission(markdownURL(sessionID))
    }

    func requireSafeRegularFile(_ url: URL, sessionID: UUID) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw TranscriptMigrationError.unsafeTranscriptFile(sessionID)
        }
    }

    func setPrivateFilePermission(_ url: URL) throws {
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: 0o600)],
            ofItemAtPath: url.path
        )
    }

    func markdownHeader(
        for session: TranscriptSession,
        integrity: StoredTranscriptIntegrity = .active
    ) -> String {
        TranscriptMarkdown.header(for: session, integrity: integrity)
    }

    func markdown(for entry: TranscriptEntry) -> String {
        TranscriptMarkdown.entry(entry)
    }

    func completeMarkdown(
        for session: TranscriptSession,
        finalization: TranscriptFinalization
    ) -> String {
        completeMarkdown(for: session, integrity: finalization.integrity)
    }

    func completeMarkdown(
        for session: TranscriptSession,
        integrity: StoredTranscriptIntegrity
    ) -> String {
        markdownHeader(for: session, integrity: integrity)
            + session.entries.map(markdown).joined()
            + "---\n\n## 记录状态\n\n\(integrity.markdownNotice)\n"
    }

    func loadEntryIDsIfNeeded(sessionID: UUID) throws -> Set<UUID> {
        if let loaded = entryIDs[sessionID] { return loaded }
        let manifest = try recoveryManifest(sessionID: sessionID)
        let identifiers = Set(try readEntries(sessionID: sessionID, manifest: manifest).map(\.id))
        entryIDs[sessionID] = identifiers
        return identifiers
    }

    func readEntries(
        sessionID: UUID,
        manifest: SessionManifest
    ) throws -> [TranscriptEntry] {
        guard manifest.storesSourceOnlyEntries else {
            throw TranscriptMigrationError.legacyContentNotMigrated(sessionID)
        }
        try requireSafeRegularFile(jsonLinesURL(sessionID), sessionID: sessionID)
        let data = try readBoundedData(
            at: jsonLinesURL(sessionID),
            maximumBytes: recoveryLimits.maximumTranscriptBytes
        )
        let decoder = lineDecoder()
        return try decodeSourceEntries(data, decoder: decoder)
    }

    func decodeSourceEntries(_ data: Data, decoder: JSONDecoder) throws -> [TranscriptEntry] {
        let lines = data.split(separator: 0x0A)
        guard lines.count <= recoveryLimits.maximumEntriesPerSession else {
            throw TranscriptRecoveryFileError.entryLimitExceeded(
                recoveryLimits.maximumEntriesPerSession
            )
        }
        return try lines.map {
            try decoder.decode(StoredSourceTranscriptEntry.self, from: Data($0)).transcriptEntry
        }
    }

    func decodeLegacyOrSourceEntries(_ data: Data) throws -> [TranscriptEntry] {
        let lines = data.split(separator: 0x0A)
        guard lines.count <= recoveryLimits.maximumEntriesPerSession else {
            throw TranscriptRecoveryFileError.entryLimitExceeded(
                recoveryLimits.maximumEntriesPerSession
            )
        }
        let decoder = lineDecoder()
        return try lines.map { line in
            let encoded = Data(line)
            if let legacy = try? decoder.decode(TranscriptEntry.self, from: encoded) {
                return StoredSourceTranscriptEntry(legacy).transcriptEntry
            }
            return try decoder.decode(
                StoredSourceTranscriptEntry.self,
                from: encoded
            ).transcriptEntry
        }
    }

    func sessionDirectory(_ id: UUID) -> URL {
        root.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    func manifestURL(_ id: UUID) -> URL {
        sessionDirectory(id).appending(path: "session.json")
    }

    func jsonLinesURL(_ id: UUID) -> URL {
        sessionDirectory(id).appending(path: "transcript.jsonl")
    }

    func markdownURL(_ id: UUID) -> URL {
        sessionDirectory(id).appending(path: "transcript.md")
    }

    func lineEncoder() -> JSONEncoder { configuredEncoder() }
    func lineDecoder() -> JSONDecoder { decoder() }

    func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func configuredEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension StoredTranscriptIntegrity {
    fileprivate var markdownNotice: String {
        switch self {
        case .complete:
            "会议记录完整。"
        case .incomplete:
            "会议记录未完整处理，请结合完整录音核对。"
        case .recoveredAfterInterruption:
            "会议记录已在意外中断后恢复，内容可能不完整，请结合录音核对。"
        case .active:
            "会议记录仍在处理中。"
        }
    }
}
