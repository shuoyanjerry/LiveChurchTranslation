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

    func recentCallCount() -> Int { recentCalls }

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

    func isSessionActive(sessionID: UUID) -> Bool { false }
    func delete(sessionID: UUID) {}

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

    func importAudio(from _: URL, mode _: TranslationMode) async throws {
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
    integrity: StoredTranscriptIntegrity = .complete
) -> StoredSessionSummary {
    StoredSessionSummary(
        id: id,
        startedAt: Date(),
        endedAt: Date(),
        entryCount: 0,
        location: URL(fileURLWithPath: "/tmp/\(id.uuidString)"),
        title: "导入音频",
        kind: .importedAudio,
        integrity: integrity
    )
}
