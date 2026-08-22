import Foundation
import PersistenceAPI
import TranscriptAPI

extension FileTranscriptStore {
    func writeManifest(for session: TranscriptSession) throws {
        let manifest = SessionManifest(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            entryCount: session.entries.count
        )
        try jsonEncoder.encode(manifest).write(to: manifestURL(session.id), options: .atomic)
    }

    func readSummary(_ directory: URL) throws -> StoredSessionSummary? {
        let url = directory.appending(path: "session.json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let manifest = try decoder().decode(SessionManifest.self, from: Data(contentsOf: url))
        return StoredSessionSummary(
            id: manifest.id,
            startedAt: manifest.startedAt,
            endedAt: manifest.endedAt,
            entryCount: manifest.entryCount,
            location: directory
        )
    }

    func append(_ data: Data, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    func markdownHeader(for session: TranscriptSession) -> String {
        "# Quiet Liturgy Reader\n\nStarted: \(session.startedAt.formatted())\n\n"
    }

    func markdown(for entry: TranscriptEntry) -> String {
        "## \(entry.sequence)\n\n\(entry.targetText)\n\n> \(entry.sourceText)\n\n"
    }

    func completeMarkdown(for session: TranscriptSession) -> String {
        markdownHeader(for: session)
            + session.entries.map(markdown).joined()
            + "\n---\nSession complete.\n"
    }

    func loadEntryIDsIfNeeded(sessionID: UUID) throws -> Set<UUID> {
        if let loaded = entryIDs[sessionID] { return loaded }
        let identifiers = Set(try readEntries(sessionID: sessionID).map(\.id))
        entryIDs[sessionID] = identifiers
        return identifiers
    }

    func readEntries(sessionID: UUID) throws -> [TranscriptEntry] {
        let data = try Data(contentsOf: jsonLinesURL(sessionID))
        let decoder = lineDecoder()
        return try data.split(separator: 0x0A).map {
            try decoder.decode(TranscriptEntry.self, from: Data($0))
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
