import AudioCaptureAPI
import SettingsAPI

extension LiveReaderViewModel {
    public func toggleSession() async {
        if isRunning {
            await controller.stop()
        } else if externalSessionControlLock {
            presentedError = "请先等待当前音频导入完成，再开始实时翻译。"
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

    public func selectTranslationMode(_ mode: TranslationMode) async {
        guard !sessionControlsLocked, mode != settings.translationMode else { return }
        let previous = settings
        settings.translationMode = mode
        if !(await saveSettings()) {
            settings = previous
        }
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
