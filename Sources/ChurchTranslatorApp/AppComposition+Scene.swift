import AudioImportAPI
import LiveReader
import SessionManagement
import SessionManagementAPI

extension AppComposition {
    static func makeSceneDependencies(
        services: AppServiceGraph,
        controller: LiveSessionCoordinator,
        directories: AppDirectories
    ) -> AppSceneDependencies {
        let viewModel = LiveReaderViewModel(
            controller: controller,
            modelPreparation: services.modelPreparation,
            capture: services.capture,
            glossary: services.glossary,
            settingsStore: services.settings
        )
        let remote = makeRemoteServices(controller: controller, settings: services.settings)
        let audioImporter = makeAudioImporter(services: services, directories: directories)
        let libraryViewModel = SessionLibraryViewModel(
            store: services.transcripts,
            recoveryArtifacts: services.recovery
        )
        let permissionCoordinator = MicrophonePermissionCoordinator(
            permissionClient: AudioCaptureMicrophonePermissionClient(capture: services.capture),
            settingsOpener: MacMicrophoneSettingsOpener()
        )
        startBackgroundServices(remote: remote, services: services, library: libraryViewModel)
        return AppSceneDependencies(
            controller: controller,
            viewModel: viewModel,
            libraryViewModel: libraryViewModel,
            permissionCoordinator: permissionCoordinator,
            sharingFeature: remote.sharingFeature,
            projectionAdapter: remote.projectionAdapter,
            audioImporter: audioImporter,
            modelPreparations: [
                services.modelPreparation,
                services.transcriptionModelPreparation,
            ]
        )
    }

    private static func startBackgroundServices(
        remote: RemoteServices,
        services: AppServiceGraph,
        library: SessionLibraryViewModel
    ) {
        Task { await remote.projectionAdapter.start() }
        Task {
            _ = await recoverInterruptedRecordings(services: services)
            await library.load()
        }
    }
}
