import AudioImportAPI
import Foundation
import LiveReader
import PersistenceAPI
import SettingsAPI
import Testing

@Suite @MainActor struct SessionLibraryImportTests {
    @Test func successRefreshesAndSelectsTheOnlyNewSession() async {
        let existing = librarySummary()
        let imported = librarySummary()
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = makeViewModel(store)
        await viewModel.load()
        let importer = SessionLibraryImporterFake { await store.add(imported) }

        await importAudio(with: importer, into: viewModel)

        #expect(viewModel.sessions.map(\.id) == [imported.id, existing.id])
        #expect(viewModel.selectedSessionID == imported.id)
        #expect(viewModel.selectedSession?.id == imported.id)
        #expect(viewModel.presentedError == nil)
        #expect(await store.recentCallCount() == 3)
    }

    @Test func cancellationStillRefreshesWithoutShowingAnError() async {
        let existing = librarySummary()
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = makeViewModel(store)
        await viewModel.load()
        let importer = SessionLibraryImporterFake { throw AudioImportError.cancelled }

        await importAudio(with: importer, into: viewModel)

        #expect(viewModel.selectedSessionID == existing.id)
        #expect(viewModel.presentedError == nil)
        #expect(await store.recentCallCount() == 3)
    }

    @Test func cancellationDoesNotSelectAnUnrelatedNewSession() async {
        let existing = librarySummary()
        let external = librarySummary()
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = makeViewModel(store)
        await viewModel.load()
        let importer = SessionLibraryImporterFake {
            await store.add(external)
            throw AudioImportError.cancelled
        }

        await importAudio(with: importer, into: viewModel)

        #expect(viewModel.sessions.first?.id == external.id)
        #expect(viewModel.selectedSessionID == existing.id)
        #expect(viewModel.presentedError == nil)
    }

    @Test func partialSaveUsesIdentityWhenAnotherSessionAlsoAppears() async {
        let existing = librarySummary()
        let imported = librarySummary(integrity: .incomplete)
        let external = librarySummary()
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = makeViewModel(store)
        await viewModel.load()
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
}

extension SessionLibraryImportTests {
    @Test func multipleNewSessionsNeverCauseAGuessedSelection() async {
        let existing = librarySummary()
        let firstNew = librarySummary()
        let secondNew = librarySummary()
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = makeViewModel(store)
        await viewModel.load()
        let importer = SessionLibraryImporterFake {
            await store.add(firstNew)
            await store.add(secondNew)
        }

        await importAudio(with: importer, into: viewModel)

        #expect(viewModel.sessions.count == 3)
        #expect(viewModel.selectedSessionID == existing.id)
        #expect(viewModel.presentedError == nil)
    }

    @Test func zeroNewSessionsKeepsTheExistingSelection() async {
        let existing = librarySummary()
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = makeViewModel(store)
        await viewModel.load()

        await importAudio(
            with: SessionLibraryImporterFake {},
            into: viewModel
        )

        #expect(viewModel.selectedSessionID == existing.id)
        #expect(viewModel.presentedError == nil)
        #expect(await store.recentCallCount() == 3)
    }

    @Test func trueFailureDoesNotSelectAnUnrelatedNewSession() async {
        let existing = librarySummary()
        let external = librarySummary()
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = makeViewModel(store)
        await viewModel.load()
        let importer = SessionLibraryImporterFake {
            await store.add(external)
            throw AudioImportError.transcriptionFailed("backend detail")
        }

        await importAudio(with: importer, into: viewModel)

        #expect(viewModel.sessions.first?.id == external.id)
        #expect(viewModel.selectedSessionID == existing.id)
        #expect(viewModel.presentedError == "音频听抄未完成，请重试。")
    }

    @Test func staleUIBaselineDoesNotMisidentifyAnExternalSessionAsTheImport() async {
        let existing = librarySummary()
        let external = librarySummary(integrity: .incomplete)
        let store = SessionLibraryStoreFake(summaries: [existing])
        let viewModel = makeViewModel(store)
        await viewModel.load()
        await store.add(external)

        await importAudio(with: SessionLibraryImporterFake {}, into: viewModel)

        #expect(viewModel.sessions.first?.id == external.id)
        #expect(viewModel.selectedSessionID == existing.id)
        #expect(viewModel.presentedError == nil)
    }

    @Test func incompleteStoredSummaryCorrectsAnOtherwiseSuccessfulOutcome() async {
        let imported = librarySummary(integrity: .incomplete)
        let store = SessionLibraryStoreFake()
        let viewModel = makeViewModel(store)
        let importer = SessionLibraryImporterFake { await store.add(imported) }

        await importAudio(with: importer, into: viewModel)

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
