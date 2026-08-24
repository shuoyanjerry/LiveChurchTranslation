import LiveReader
import SettingsAPI
import Testing

@Suite @MainActor struct ReaderPreferenceSaveConcurrencyTests {
    @Test func rapidSavesCannotOverwriteTheNewestChoice() async {
        let settings = DelayedFirstSaveSettingsStore()
        let viewModel = LiveReaderViewModel(
            controller: SessionControllerStub(),
            modelPreparation: ModelPreparationStub(),
            capture: AudioCaptureStub(),
            glossary: GlossaryStub(),
            settingsStore: settings
        )
        await viewModel.load()

        viewModel.settings.showSourceText = false
        let firstSave = Task { @MainActor in await viewModel.saveSettings() }
        await settings.waitUntilFirstSaveStarts()
        viewModel.settings.showTimestamps = false
        let secondSave = Task { @MainActor in await viewModel.saveSettings() }
        await settings.releaseFirstSave()

        #expect(await firstSave.value)
        #expect(await secondSave.value)
        let persisted = await settings.current()
        #expect(!persisted.showSourceText)
        #expect(!persisted.showTimestamps)
        #expect(!viewModel.settings.showSourceText)
        #expect(!viewModel.settings.showTimestamps)
    }
}

private actor DelayedFirstSaveSettingsStore: SettingsStore {
    private var settings = AppSettings.defaults
    private var saveCount = 0
    private var firstSaveStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstSaveContinuation: CheckedContinuation<Void, Never>?

    func load() -> AppSettings { settings }

    func save(_ newSettings: AppSettings) async {
        saveCount += 1
        if saveCount == 1 {
            firstSaveStarted = true
            startWaiters.forEach { $0.resume() }
            startWaiters.removeAll()
            await withCheckedContinuation { firstSaveContinuation = $0 }
        }
        settings = newSettings
    }

    func waitUntilFirstSaveStarts() async {
        guard !firstSaveStarted else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func releaseFirstSave() {
        firstSaveContinuation?.resume()
        firstSaveContinuation = nil
    }

    func current() -> AppSettings { settings }
}
