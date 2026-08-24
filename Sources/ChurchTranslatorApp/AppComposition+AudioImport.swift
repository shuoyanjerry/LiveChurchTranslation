import AudioFileAVFoundation
import AudioImportAPI
import AudioImportSessionAdapter
import SessionManagement

extension AppComposition {
    static func makeAudioImporter(
        services: AppServiceGraph,
        directories: AppDirectories
    ) -> any AudioImporting {
        let factory: ImportedAudioTranscriber.ControllerFactory = { url, mode, sessionTitle in
            LiveSessionCoordinator(
                dependencies: try services.makeSessionDependencies(
                    directories: directories,
                    capture: FileAudioCaptureProvider(url: url),
                    settings: ImportedAudioSettingsStore(base: services.settings, mode: mode)
                ),
                models: productionModels,
                modelPreparation: services.modelPreparation,
                sessionKind: .importedAudio,
                sessionTitle: sessionTitle ?? url.deletingPathExtension().lastPathComponent
            )
        }
        return ImportedAudioTranscriber(
            inputDeviceID: FileAudioCaptureProvider.inputID,
            makeController: factory
        )
    }
}
