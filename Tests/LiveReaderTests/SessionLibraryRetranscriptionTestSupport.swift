import AudioImportAPI
import Foundation
import LiveReader
import PersistenceAPI
import SettingsAPI

final class RetranscriptionFixture: @unchecked Sendable {
    let directory: URL
    let recordingURL: URL
    let summary: StoredSessionSummary
    let store: SessionLibraryStoreFake
    let viewModel: SessionLibraryViewModel

    @MainActor init(
        mode: TranslationMode = .mandarinToEnglish,
        integrity: StoredTranscriptIntegrity = .incomplete,
        pendingRecordCount: Int = 1,
        rejectedSentenceCount: Int = 0,
        sourceLanguage: String? = nil,
        targetLanguage: String? = nil,
        createRecording: Bool = true
    ) throws {
        directory = FileManager.default.temporaryDirectory.appending(
            path: "retranscription-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        recordingURL = directory.appending(path: "recording.caf")
        if createRecording { try Data([0, 1, 2, 3]).write(to: recordingURL) }
        summary = librarySummary(
            integrity: integrity,
            location: directory,
            title: "主日信息",
            sourceLanguage: sourceLanguage ?? mode.sourceLanguageTag,
            targetLanguage: targetLanguage ?? mode.targetLanguageTag,
            pendingRecordCount: pendingRecordCount,
            rejectedSentenceCount: rejectedSentenceCount
        )
        store = SessionLibraryStoreFake(summaries: [summary])
        viewModel = SessionLibraryViewModel(
            store: store,
            recoveryArtifacts: SessionLibraryRecoveryArtifactsFake()
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}

struct RetranscriptionCall: Sendable {
    let url: URL
    let mode: TranslationMode
    let title: String?
}

actor RetranscriptionCallRecorder {
    private var values: [RetranscriptionCall] = []

    func record(url: URL, mode: TranslationMode, title: String?) {
        values.append(RetranscriptionCall(url: url, mode: mode, title: title))
    }

    func calls() -> [RetranscriptionCall] { values }
}

struct RetranscriptionImporterFake: AudioImporting {
    let operation: @Sendable (URL, TranslationMode, String?) async throws -> Void

    init(
        operation: @escaping @Sendable (URL, TranslationMode, String?) async throws -> Void
    ) {
        self.operation = operation
    }

    init(record recorder: RetranscriptionCallRecorder) {
        operation = { url, mode, title in
            await recorder.record(url: url, mode: mode, title: title)
        }
    }

    func importAudio(
        from url: URL,
        mode: TranslationMode,
        sessionTitle: String?
    ) async throws {
        try await operation(url, mode, sessionTitle)
    }

    func cancelImport() async {}
}

actor RetranscriptionGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

enum RetranscriptionTestError: Error {
    case timedOut
}

extension Array {
    var only: Element? { count == 1 ? self[0] : nil }
}
