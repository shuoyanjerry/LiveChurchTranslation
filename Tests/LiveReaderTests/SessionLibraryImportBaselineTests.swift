import AudioImportAPI
import Foundation
import LiveReader
import PersistenceAPI
import SettingsAPI
import Testing

@Suite @MainActor struct SessionLibraryImportBaselineTests {
    @Test func failedAuthoritativeBaselineNeverGuessesFromStaleUIState() async {
        let existing = librarySummary()
        let external = librarySummary()
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = makeViewModel(store)
        await viewModel.load()
        await store.failNextRefresh()
        let importer = SessionLibraryImporterFake { await store.add(external) }

        await importAudio(with: importer, into: viewModel)

        #expect(viewModel.sessions.map(\.id) == [external.id, existing.id])
        #expect(viewModel.selectedSessionID == existing.id)
        #expect(viewModel.presentedError == nil)
        #expect(await store.recentCallCount() == 3)
    }

    @Test func explicitPartialSaveIdentityRemainsAuthoritativeWhenBaselineFails() async {
        let existing = librarySummary()
        let imported = librarySummary(integrity: .incomplete)
        let external = librarySummary()
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = makeViewModel(store)
        await viewModel.load()
        await store.failNextRefresh()
        let importer = SessionLibraryImporterFake {
            await store.add(external)
            await store.add(imported)
            throw AudioImportError.savedWithIncompleteTranscript(sessionID: imported.id)
        }

        await importAudio(with: importer, into: viewModel)

        #expect(viewModel.sessions.count == 3)
        #expect(viewModel.selectedSessionID == imported.id)
        #expect(viewModel.presentedError == "录音已保存，听抄未完整。")
    }

    private func makeViewModel(
        _ store: SessionLibraryStoreFake
    ) -> SessionLibraryViewModel {
        SessionLibraryViewModel(
            store: store,
            recoveryArtifacts: SessionLibraryRecoveryArtifactsFake()
        )
    }

    private func importAudio(
        with importer: SessionLibraryImporterFake,
        into viewModel: SessionLibraryViewModel
    ) async {
        await viewModel.importAudio(
            from: URL(fileURLWithPath: "/tmp/import.wav"),
            mode: .mandarinToEnglish,
            using: importer,
            liveSessionIsRunning: false
        )
    }
}
