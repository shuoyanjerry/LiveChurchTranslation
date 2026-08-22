import Foundation
import PersistenceAPI
import TranscriptAPI

public actor FileTranscriptStore: TranscriptStore {
    let root: URL
    let fileManager: FileManager
    let jsonEncoder: JSONEncoder
    var entryIDs: [UUID: Set<UUID>] = [:]

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
            entryIDs[session.id] = []
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func append(_ entry: TranscriptEntry, to sessionID: UUID) async throws {
        guard fileManager.fileExists(atPath: sessionDirectory(sessionID).path) else {
            throw TranscriptStoreError.sessionNotFound
        }
        do {
            let existing = try loadEntryIDsIfNeeded(sessionID: sessionID)
            guard !existing.contains(entry.id) else { return }
            let encoded = try lineEncoder().encode(entry) + Data([0x0A])
            try append(encoded, to: jsonLinesURL(sessionID))
            entryIDs[sessionID, default: []].insert(entry.id)
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func finish(_ session: TranscriptSession) async throws {
        do {
            try writeManifest(for: session)
            try completeMarkdown(for: session).write(
                to: markdownURL(session.id),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func load(sessionID: UUID) async throws -> TranscriptSession? {
        let manifest = manifestURL(sessionID)
        guard fileManager.fileExists(atPath: manifest.path) else { return nil }
        do {
            let stored = try decoder().decode(SessionManifest.self, from: Data(contentsOf: manifest))
            let entries = try readEntries(sessionID: sessionID)
            entryIDs[sessionID] = Set(entries.map(\.id))
            return TranscriptSession(
                id: stored.id,
                startedAt: stored.startedAt,
                endedAt: stored.endedAt,
                entries: entries.sorted { $0.sequence < $1.sequence }
            )
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

}
