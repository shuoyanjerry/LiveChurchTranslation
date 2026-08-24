import Foundation
import PersistenceAPI
import TranscriptAPI

public actor FileTranscriptStore: TranscriptStore, InterruptedTranscriptRecoveryStore {
    let root: URL
    let fileManager: FileManager
    let recoveryLimits: TranscriptRecoveryLimits
    let jsonEncoder: JSONEncoder
    var entryIDs: [UUID: Set<UUID>] = [:]
    var activeSessionIDs: Set<UUID> = []
    var successfulMigrationScanCompleted = false

    public init(
        root: URL,
        fileManager: FileManager = .default,
        recoveryLimits: TranscriptRecoveryLimits = TranscriptRecoveryLimits()
    ) {
        self.root = root
        self.fileManager = fileManager
        self.recoveryLimits = recoveryLimits
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        jsonEncoder = encoder
    }

    public func begin(_ session: TranscriptSession) async throws {
        do {
            let directory = sessionDirectory(session.id)
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try writeManifest(for: session, integrity: .active)
            try writeMarkdown(markdownHeader(for: session), sessionID: session.id)
            try Data().write(to: jsonLinesURL(session.id), options: .atomic)
            try setPrivateFilePermission(jsonLinesURL(session.id))
            try enforcePrivatePermissions(sessionID: session.id)
            entryIDs[session.id] = []
            activeSessionIDs.insert(session.id)
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func append(_ entry: TranscriptEntry, to sessionID: UUID) async throws {
        guard fileManager.fileExists(atPath: sessionDirectory(sessionID).path) else {
            throw TranscriptStoreError.sessionNotFound
        }
        do {
            if !activeSessionIDs.contains(sessionID) {
                try migrateLegacySessionToSourceOnly(sessionID: sessionID)
            }
            let existing = try loadEntryIDsIfNeeded(sessionID: sessionID)
            guard !existing.contains(entry.id) else { return }
            let encoded = try lineEncoder().encode(StoredSourceTranscriptEntry(entry)) + Data([0x0A])
            try append(encoded, to: jsonLinesURL(sessionID))
            entryIDs[sessionID, default: []].insert(entry.id)
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func finish(
        _ session: TranscriptSession,
        finalization: TranscriptFinalization
    ) async throws {
        defer { activeSessionIDs.remove(session.id) }
        do {
            let committedFinalization = try mergedFinalization(
                sessionID: session.id,
                current: finalization
            )
            try writeEntries(session.entries, sessionID: session.id)
            try writeMarkdown(
                completeMarkdown(for: session, finalization: committedFinalization),
                sessionID: session.id
            )
            try writeManifest(for: session, finalization: committedFinalization)
            try enforcePrivatePermissions(sessionID: session.id)
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func load(sessionID: UUID) async throws -> TranscriptSession? {
        let manifest = manifestURL(sessionID)
        guard fileManager.fileExists(atPath: manifest.path) else { return nil }
        do {
            try migrateLegacySessionToSourceOnly(sessionID: sessionID)
            let stored = try recoveryManifest(sessionID: sessionID)
            let entries = try readEntries(sessionID: sessionID, manifest: stored)
            entryIDs[sessionID] = Set(entries.map(\.id))
            return TranscriptSession(
                id: stored.id,
                startedAt: stored.startedAt,
                endedAt: stored.endedAt,
                entries: entries.sorted { $0.sequence < $1.sequence },
                title: stored.title,
                kind: stored.kind,
                sourceLanguage: stored.sourceLanguage,
                targetLanguage: stored.targetLanguage
            )
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func recentSessions(limit: Int) async throws -> [StoredSessionSummary] {
        do {
            try migrateLegacySessionsToSourceOnly()
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

extension FileTranscriptStore {
    public func delete(sessionID: UUID) async throws {
        guard !isSessionActive(sessionID: sessionID) else {
            throw TranscriptStoreError.sessionActive
        }
        let directory = sessionDirectory(sessionID)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw TranscriptStoreError.sessionNotFound
        }
        do {
            let values = try directory.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw TranscriptStoreError.invalidSessionDirectory
            }
            try fileManager.removeItem(at: directory)
            entryIDs.removeValue(forKey: sessionID)
        } catch let error as TranscriptStoreError {
            throw error
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    public func isSessionActive(sessionID: UUID) -> Bool {
        activeSessionIDs.contains(sessionID) || hasRecordingActivityArtifact(sessionID: sessionID)
    }

    func hasRecordingActivityArtifact(sessionID: UUID) -> Bool {
        let directory = sessionDirectory(sessionID)
        return [".recording-active", "recording.partial.caf"].contains {
            fileManager.fileExists(atPath: directory.appending(path: $0).path)
        }
    }
}
