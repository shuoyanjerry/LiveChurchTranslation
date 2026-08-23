import AudioCaptureAPI
import Foundation
import GlossaryAPI
import LiveReader
import SessionManagementAPI
import SettingsAPI
import Testing

@Suite @MainActor struct SessionControlLockTests {
    @Test func audioImportLockBlocksModeInputAndLiveStartButAllowsReaderPreferences() async {
        let controller = SessionControllerStub()
        let settings = SettingsStoreStub()
        let viewModel = LiveReaderViewModel(
            controller: controller,
            modelPreparation: ModelPreparationStub(),
            capture: AudioCaptureStub(),
            glossary: GlossaryStub(),
            settingsStore: settings
        )
        await viewModel.load()
        viewModel.setExternalSessionControlLock(true)

        await viewModel.selectTranslationMode(.englishToSimplifiedChinese)
        await viewModel.selectAudioInput(AudioInputID(rawValue: "import-race-mic"))
        #expect(viewModel.settings.translationMode == .mandarinToEnglish)
        #expect(viewModel.selectedInputID == nil)

        viewModel.settings.translationMode = .englishToSimplifiedChinese
        viewModel.settings.readerFontSize = 36
        viewModel.settings.showSourceText = false
        viewModel.selectedInputID = AudioInputID(rawValue: "bypass-attempt")
        #expect(await viewModel.saveSettings())
        let persisted = await settings.current()
        #expect(persisted.translationMode == .mandarinToEnglish)
        #expect(persisted.selectedAudioDeviceID == nil)
        #expect(persisted.readerFontSize == 36)
        #expect(!persisted.showSourceText)

        await viewModel.toggleSession()
        #expect(await controller.startCount() == 0)
        #expect(!viewModel.presentsRecordingNotice)
        #expect(viewModel.presentedError?.contains("audio import") == true)
    }

    @Test func controlsUnlockAfterImportFinishes() async {
        let settings = SettingsStoreStub()
        let viewModel = LiveReaderViewModel(
            controller: SessionControllerStub(),
            modelPreparation: ModelPreparationStub(),
            capture: AudioCaptureStub(),
            glossary: GlossaryStub(),
            settingsStore: settings
        )
        await viewModel.load()
        viewModel.setExternalSessionControlLock(true)
        viewModel.setExternalSessionControlLock(false)

        await viewModel.selectTranslationMode(.englishToSimplifiedChinese)
        await viewModel.selectAudioInput(AudioInputID(rawValue: "sanctuary-mic"))

        let persisted = await settings.current()
        #expect(persisted.translationMode == .englishToSimplifiedChinese)
        #expect(persisted.selectedAudioDeviceID == "sanctuary-mic")
    }

    @Test func loadStartsModelPreparationWithoutUserAction() async {
        let modelPreparation = ModelPreparationStub()
        let viewModel = LiveReaderViewModel(
            controller: SessionControllerStub(),
            modelPreparation: modelPreparation,
            capture: AudioCaptureStub(),
            glossary: GlossaryStub(),
            settingsStore: SettingsStoreStub()
        )

        await viewModel.load()
        for _ in 0..<20 {
            if await modelPreparation.prepareCount() > 0 { break }
            await Task.yield()
        }

        #expect(await modelPreparation.prepareCount() == 1)
    }
}

private actor ModelPreparationStub: ModelPreparationController {
    private var preparations = 0

    func prepareModels() { preparations += 1 }
    func retryModelPreparation() { preparations += 1 }
    func currentModelPreparation() -> ModelPreparationSnapshot {
        ModelPreparationSnapshot(phase: .ready, message: "Models ready")
    }
    func modelPreparationEvents() -> AsyncStream<ModelPreparationSnapshot> {
        AsyncStream { continuation in
            continuation.yield(currentModelPreparation())
            continuation.finish()
        }
    }
    func prepareCount() -> Int { preparations }
}

private actor SessionControllerStub: LiveSessionController {
    private var starts = 0

    func start(inputDeviceID _: AudioInputID?) { starts += 1 }
    func stop() {}
    func currentSnapshot() -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: nil,
            phase: .idle,
            transcript: [],
            modelStatus: nil,
            statusMessage: "Ready"
        )
    }
    func events() -> AsyncStream<LiveSessionEvent> { AsyncStream { $0.finish() } }
    func startCount() -> Int { starts }
}

private struct AudioCaptureStub: AudioCaptureProvider {
    func authorizationStatus() -> AudioCapturePermission { .authorized }
    func requestPermission() -> AudioCapturePermission { .authorized }
    func availableInputs() -> [AudioInputDevice] { [] }
    func startCapture(
        request _: AudioCaptureRequest
    ) -> AsyncThrowingStream<AudioFrame, any Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func stopCapture() {}
}

private actor GlossaryStub: GlossaryService {
    func snapshot() -> GlossarySnapshot { GlossarySnapshot(revision: 0, entries: []) }
    func replace(with _: [GlossaryEntry]) {}
    func upsert(_: GlossaryEntry) {}
    func remove(id _: UUID) {}
    func restoreDefaults() {}
}

private actor SettingsStoreStub: SettingsStore {
    private var settings = AppSettings.defaults

    func load() -> AppSettings { settings }
    func save(_ settings: AppSettings) { self.settings = settings }
    func current() -> AppSettings { settings }
}
