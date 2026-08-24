import AudioCaptureAPI
import SettingsAPI

extension LiveReaderViewModel {
    public func toggleSession() async {
        if isRunning {
            await controller.stop()
        } else if externalSessionControlLock {
            presentedError = "请先完成当前音频导入。"
        } else {
            presentsRecordingNotice = true
        }
    }

    public func startRecordingAndTranslation() async {
        presentsRecordingNotice = false
        guard !sessionControlsLocked else { return }
        guard await saveSettings() else { return }
        await controller.start(inputDeviceID: selectedInputID)
    }

    public func retryModelPreparation() async {
        await modelPreparation.retryModelPreparation()
    }

    @discardableResult
    public func selectTranslationMode(_ mode: TranslationMode) async -> Bool {
        guard !sessionControlsLocked else { return false }
        guard mode != settings.translationMode else { return true }
        let previous = settings
        settings.translationMode = mode
        if !(await saveSettings()) {
            settings = previous
            return false
        }
        return true
    }

    public func selectAudioInput(_ id: AudioInputID?) async {
        guard !sessionControlsLocked, id != selectedInputID else { return }
        let previousID = selectedInputID
        selectedInputID = id
        if !(await saveSettings()) {
            selectedInputID = previousID
        }
    }
}
