import Foundation
import PersistenceAPI
import TranscriptAPI

public actor FileTranscriptStore: TranscriptStore {
    private let root: URL
    private let fileManager: FileManager
    private let jsonEncoder: JSONEncoder

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        jsonEncoder = encoder
    }

    public func begin(_ session: TranscriptSession) async throws {
        do {
            let directory = sessionDirectory(session.id)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try writeManifest(for: session)
            try markdownHeader(for: session).write(
                to: markdownURL(session.id),
                atomically: true,
                encoding: .utf8
            )
            try Data().write(to: jsonLinesURL(session.id), options: .atomic)
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func append(_ entry: TranscriptEntry, to sessionID: UUID) async throws {
        guard fileManager.fileExists(atPath: sessionDirectory(sessionID).path) else {
            throw TranscriptStoreError.sessionNotFound
        }
        do {
            let encoded = try lineEncoder().encode(entry) + Data([0x0A])
            try append(encoded, to: jsonLinesURL(sessionID))
            try append(Data(markdown(for: entry).utf8), to: markdownURL(sessionID))
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func finish(_ session: TranscriptSession) async throws {
        do {
            try writeManifest(for: session)
            try append(Data("\n---\nSession complete.\n".utf8), to: markdownURL(session.id))
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func recentSessions(limit: Int) async throws -> [StoredSessionSummary] {
        do {
            let urls = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            let summaries = try urls.compactMap(readSummary)
            return Array(summaries.sorted { $0.startedAt > $1.startedAt }.prefix(max(0, limit)))
        } catch  where (error as NSError).code == NSFileReadNoSuchFileError {
            return []
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    private func writeManifest(for session: TranscriptSession) throws {
        let manifest = SessionManifest(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            entryCount: session.entries.count
        )
        try jsonEncoder.encode(manifest).write(to: manifestURL(session.id), options: .atomic)
    }

    private func readSummary(_ directory: URL) throws -> StoredSessionSummary? {
        let manifestURL = directory.appending(path: "session.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else { return nil }
        let data = try Data(contentsOf: manifestURL)
        let manifest = try decoder().decode(SessionManifest.self, from: data)
        return StoredSessionSummary(
            id: manifest.id,
            startedAt: manifest.startedAt,
            endedAt: manifest.endedAt,
            entryCount: manifest.entryCount,
            location: directory
        )
    }

    private func append(_ data: Data, to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    private func markdownHeader(for session: TranscriptSession) -> String {
        "# Live Church Translation\n\nStarted: \(session.startedAt.formatted())\n\n"
    }

    private func markdown(for entry: TranscriptEntry) -> String {
        "## \(entry.sequence)\n\n\(entry.targetText)\n\n> \(entry.sourceText)\n\n"
    }

    private func sessionDirectory(_ id: UUID) -> URL {
        root.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    private func manifestURL(_ id: UUID) -> URL { sessionDirectory(id).appending(path: "session.json") }
    private func jsonLinesURL(_ id: UUID) -> URL { sessionDirectory(id).appending(path: "transcript.jsonl") }
    private func markdownURL(_ id: UUID) -> URL { sessionDirectory(id).appending(path: "transcript.md") }

    private func lineEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
