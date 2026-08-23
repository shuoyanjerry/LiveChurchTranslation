import AudioCaptureAPI
import DiagnosticsAPI
import Foundation
import GlossaryAPI
import LoggingAPI
import PersistenceAPI
import SettingsAPI
import TranscriptAPI

actor FakeGlossaryService: GlossaryService {
    private var entries: [GlossaryEntry]

    init(entries: [GlossaryEntry]) { self.entries = entries }

    func snapshot() -> GlossarySnapshot {
        GlossarySnapshot(revision: 1, entries: entries)
    }

    func replace(with entries: [GlossaryEntry]) { self.entries = entries }
    func upsert(_ entry: GlossaryEntry) { entries.append(entry) }
    func remove(id: UUID) { entries.removeAll { $0.id == id } }
    func restoreDefaults() { entries = DefaultGlossary.entries }
}

actor FakeTranscriptStore: TranscriptStore {
    private let failAppend: Bool
    private let failFinish: Bool
    private var begun: [TranscriptSession] = []
    private var appendAttempts = 0
    private var appended: [TranscriptEntry] = []
    private var finished: [TranscriptSession] = []
    private var finalizations: [TranscriptFinalization] = []

    init(failAppend: Bool, failFinish: Bool = false) {
        self.failAppend = failAppend
        self.failFinish = failFinish
    }

    func begin(_ session: TranscriptSession) { begun.append(session) }

    func append(_ entry: TranscriptEntry, to _: UUID) throws {
        appendAttempts += 1
        if failAppend { throw SessionPipelineFakeError.storage }
        appended.append(entry)
    }

    func load(sessionID: UUID) -> TranscriptSession? {
        guard let session = begun.first(where: { $0.id == sessionID }) else { return nil }
        return TranscriptSession(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            entries: appended,
            title: session.title,
            kind: session.kind,
            sourceLanguage: session.sourceLanguage,
            targetLanguage: session.targetLanguage
        )
    }

    func finish(
        _ session: TranscriptSession,
        finalization: TranscriptFinalization
    ) throws {
        if failFinish { throw SessionPipelineFakeError.finalization }
        finished.append(session)
        finalizations.append(finalization)
    }
    func recentSessions(limit _: Int) -> [StoredSessionSummary] { [] }
    func isSessionActive(sessionID _: UUID) -> Bool { false }
    func delete(sessionID _: UUID) {}

    func begunSessions() -> [TranscriptSession] { begun }
    func seed(_ entry: TranscriptEntry) { appended.append(entry) }
    func attemptedAppendCount() -> Int { appendAttempts }
    func persistedEntries() -> [TranscriptEntry] { appended }
    func finishedSessions() -> [TranscriptSession] { finished }
    func transcriptFinalizations() -> [TranscriptFinalization] { finalizations }
}

actor FakeSettingsStore: SettingsStore {
    private var settings: AppSettings

    init(settings: AppSettings = .defaults) {
        self.settings = settings
    }

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
}

struct NoopAppLogger: AppLogger {
    func write(_: LogRecord) {}
}

actor FakeDiagnosticsRecorder: DiagnosticsRecorder {
    private var events: [DiagnosticEvent] = []

    func record(_ event: DiagnosticEvent) { events.append(event) }
    func recent(limit: Int) -> [DiagnosticEvent] { Array(events.suffix(limit)) }

    func export() throws -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("diagnostics.json")
    }

    func recordedEvents() -> [DiagnosticEvent] { events }
}
