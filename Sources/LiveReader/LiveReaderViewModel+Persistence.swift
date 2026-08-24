import AudioCaptureAPI
import GlossaryAPI
import SettingsAPI

extension LiveReaderViewModel {
    @discardableResult
    public func saveGlossary(_ entries: [GlossaryEntry]) async -> Bool {
        do {
            try await glossary.replace(with: entries)
            glossaryEntries = try await glossary.snapshot().entries
            return true
        } catch {
            return false
        }
    }

    public func restoreGlossary() async -> [GlossaryEntry]? {
        do {
            try await glossary.restoreDefaults()
            glossaryEntries = try await glossary.snapshot().entries
            return glossaryEntries
        } catch {
            return nil
        }
    }

    @discardableResult
    public func saveSettings() async -> Bool {
        do {
            var settingsToSave = settings
            if sessionControlsLocked {
                let persisted = try await settingsStore.load()
                settingsToSave.translationMode = persisted.translationMode
                settingsToSave.selectedAudioDeviceID = persisted.selectedAudioDeviceID
                settings.translationMode = persisted.translationMode
                selectedInputID = persisted.selectedAudioDeviceID.map(AudioInputID.init(rawValue:))
            } else {
                settingsToSave.selectedAudioDeviceID = selectedInputID?.rawValue
            }
            try await settingsStore.save(settingsToSave)
            settings = settingsToSave
            return true
        } catch {
            presentedError = "设置未保存，请重试。"
            return false
        }
    }
}
