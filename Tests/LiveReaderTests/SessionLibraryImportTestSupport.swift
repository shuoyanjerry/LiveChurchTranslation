import AudioImportAPI
import Foundation
import PersistenceAPI
import SettingsAPI
import TranscriptAPI
import UtteranceRecoveryAPI

actor SessionLibraryStoreFake: TranscriptStore {
    private var storedSummaries: [StoredSessionSummary]
    private var storedSessions: [UUID: TranscriptSession]
    private var recentCalls = 0
    private var failsNextRecent = false
    private var activeSessionIDs = Set<UUID>()
    private var deletedSessionIDs: [UUID] = []

    init(summaries: [StoredSessionSummary] = []) {
        storedSummaries = summaries
        storedSessions = Dictionary(
            uniqueKeysWithValues: summaries.map { summary in
                (summary.id, Self.session(for: summary))
            })
    }

    func add(_ summary: StoredSessionSummary) {
        storedSummaries.insert(summary, at: 0)
        storedSessions[summary.id] = Self.session(for: summary)
    }

    func failNextRefresh() {
        failsNextRecent = true
    }

    func setActive(_ active: Bool, sessionID: UUID) {
        if active {
            activeSessionIDs.insert(sessionID)
        } else {
            activeSessionIDs.remove(sessionID)
        }
    }

    func recentCallCount() -> Int { recentCalls }
    func deletedIDs() -> [UUID] { deletedSessionIDs }

    func begin(_ session: TranscriptSession) {}
    func append(_ entry: TranscriptEntry, to sessionID: UUID) {}

    func load(sessionID: UUID) -> TranscriptSession? {
        storedSessions[sessionID]
    }

    func finish(
        _ session: TranscriptSession,
        finalization: TranscriptFinalization
    ) {}

    func recentSessions(limit: Int) throws -> [StoredSessionSummary] {
        recentCalls += 1
        if failsNextRecent {
            failsNextRecent = false
            throw SessionLibraryTestError.refreshFailed
        }
        return Array(storedSummaries.prefix(limit))
    }

    func isSessionActive(sessionID: UUID) -> Bool {
        activeSessionIDs.contains(sessionID)
    }

    func delete(sessionID: UUID) {
        deletedSessionIDs.append(sessionID)
        storedSummaries.removeAll { $0.id == sessionID }
        storedSessions[sessionID] = nil
    }

    private static func session(for summary: StoredSessionSummary) -> TranscriptSession {
        TranscriptSession(
            id: summary.id,
            startedAt: summary.startedAt,
            endedAt: summary.endedAt,
            entries: [],
            title: summary.title,
            kind: summary.kind,
            sourceLanguage: summary.sourceLanguage,
            targetLanguage: summary.targetLanguage
        )
    }
}

struct SessionLibraryImporterFake: AudioImporting {
    let operation: @Sendable () async throws -> Void

    func importAudio(
        from _: URL,
        mode _: TranslationMode,
        sessionTitle _: String?
    ) async throws {
        try await operation()
    }

    func cancelImport() async {}
}

struct SessionLibraryRecoveryArtifactsFake: SessionRecoveryArtifactDeleting {
    func deleteArtifacts(for _: UUID) async throws {}
}

enum SessionLibraryTestError: Error {
    case refreshFailed
}

func librarySummary(
    id: UUID = UUID(),
    integrity: StoredTranscriptIntegrity = .complete,
    location: URL? = nil,
    title: String = "导入音频",
    sourceLanguage: String = "zh-Hans",
    targetLanguage: String = "en",
    pendingRecordCount: Int = 0,
    rejectedSentenceCount: Int = 0
) -> StoredSessionSummary {
    StoredSessionSummary(
        id: id,
        startedAt: Date(),
        endedAt: Date(),
        entryCount: 0,
        location: location ?? URL(fileURLWithPath: "/tmp/\(id.uuidString)"),
        title: title,
        kind: .importedAudio,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        integrity: integrity,
        pendingRecordCount: pendingRecordCount,
        rejectedSentenceCount: rejectedSentenceCount
    )
}
