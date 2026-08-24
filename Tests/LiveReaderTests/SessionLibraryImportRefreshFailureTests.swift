import AudioImportAPI
import Foundation
import LiveReader
import PersistenceAPI
import SettingsAPI
import Testing

@Suite @MainActor struct SessionLibraryImportRefreshFailureTests {
    @Test(arguments: ImportRefreshFailureScenario.allCases)
    func terminalMeaningSurvivesARefreshFailure(
        _ scenario: ImportRefreshFailureScenario
    ) async {
        let existing = librarySummary()
        let imported = librarySummary(integrity: scenario.integrity)
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = SessionLibraryViewModel(
            store: store,
            recoveryArtifacts: SessionLibraryRecoveryArtifactsFake()
        )
        await viewModel.load()
        let importer = SessionLibraryImporterFake {
            await store.failNextRefresh()
            try await scenario.run(store: store, imported: imported)
        }

        await viewModel.importAudio(
            from: URL(fileURLWithPath: "/tmp/import.wav"),
            mode: .englishToSimplifiedChinese,
            using: importer,
            liveSessionIsRunning: false
        )

        #expect(viewModel.sessions.map(\.id) == [existing.id])
        #expect(viewModel.selectedSessionID == existing.id)
        #expect(viewModel.presentedError == scenario.expectedMessage)
        #expect(await store.recentCallCount() == 3)
    }
}

enum ImportRefreshFailureScenario: CaseIterable, Equatable, Sendable {
    case saved
    case cancelled
    case savedIncomplete
    case failed

    var integrity: StoredTranscriptIntegrity {
        self == .savedIncomplete ? .incomplete : .complete
    }

    var expectedMessage: String {
        switch self {
        case .saved: "录音已保存，资料库暂未更新，请重试。"
        case .cancelled: "资料库暂未更新，请重试。"
        case .savedIncomplete:
            "录音已保存，听抄未完整。资料库暂未更新，请重试。"
        case .failed: "媒体听抄未完成，资料库暂未更新。请确认文件包含可播放的音轨后重试。"
        }
    }

    func run(
        store: SessionLibraryStoreFake,
        imported: StoredSessionSummary
    ) async throws {
        switch self {
        case .saved:
            await store.add(imported)
        case .cancelled:
            throw AudioImportError.cancelled
        case .savedIncomplete:
            await store.add(imported)
            throw AudioImportError.savedWithIncompleteTranscript(sessionID: imported.id)
        case .failed:
            throw AudioImportError.transcriptionFailed("backend detail")
        }
    }
}
