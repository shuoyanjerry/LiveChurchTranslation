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
        settingsSaveGeneration += 1
        let generation = settingsSaveGeneration
        let requestedSettings = settings
        let requestedInputID = selectedInputID
        let controlsLocked = sessionControlsLocked
        let precedingSave = settingsSaveTail
        let store = settingsStore
        let operation = Task {
            await precedingSave?.value
            var settingsToSave = requestedSettings
            if controlsLocked {
                let persisted = try await store.load()
                settingsToSave.translationMode = persisted.translationMode
                settingsToSave.selectedAudioDeviceID = persisted.selectedAudioDeviceID
            } else {
                settingsToSave.selectedAudioDeviceID = requestedInputID?.rawValue
            }
            try await store.save(settingsToSave)
            return settingsToSave
        }
        settingsSaveTail = Task { _ = try? await operation.value }
        do {
            let settingsToSave = try await operation.value
            guard generation == settingsSaveGeneration else { return true }
            settings = settingsToSave
            if controlsLocked {
                selectedInputID = settingsToSave.selectedAudioDeviceID.map(AudioInputID.init(rawValue:))
            }
            return true
        } catch {
            guard generation == settingsSaveGeneration else { return true }
            presentedError = "设置未保存，请重试。"
            return false
        }
    }
}
