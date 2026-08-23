import LiveReader
import AudioFileAVFoundation
import RemoteControlCore
import RemoteControlSessionAdapter
import RemoteDiscoveryBonjour
import RemotePairingCore
import RemoteProjectionCore
import RemoteProjectionSessionAdapter
import RemoteSharingFeature
import RemoteSharingFeatureAPI
import RemoteTransportAPI
import RemoteTransportNetwork
import RemoteWebAssets
import SessionManagement
import SettingsAPI

struct AppSceneDependencies {
    let controller: LiveSessionCoordinator
    let viewModel: LiveReaderViewModel
    let libraryViewModel: SessionLibraryViewModel
    let sharingFeature: any LocalSharingFeature
    let projectionAdapter: LiveSessionProjectionAdapter
    let audioImporter: any AudioImporting
}

@MainActor
enum AppComposition {
    static func build() throws -> AppSceneDependencies {
        let directories = try AppDirectories.production()
        let services = try AppServiceGraph(directories: directories)
        let controller = try makeController(services: services, directories: directories)
        let viewModel = LiveReaderViewModel(
            controller: controller,
            capture: services.capture,
            glossary: services.glossary,
            settingsStore: services.settings
        )
        let remote = makeRemoteServices(controller: controller, settings: services.settings)
        let audioImporter = makeAudioImporter(services: services, directories: directories)
        Task { await remote.projectionAdapter.start() }
        Task { await recoverInterruptedRecordings(services: services) }
        return AppSceneDependencies(
            controller: controller,
            viewModel: viewModel,
            libraryViewModel: SessionLibraryViewModel(store: services.transcripts),
            sharingFeature: remote.sharingFeature,
            projectionAdapter: remote.projectionAdapter,
            audioImporter: audioImporter
        )
    }

    private static func makeController(
        services: AppServiceGraph,
        directories: AppDirectories
    ) throws -> LiveSessionCoordinator {
        LiveSessionCoordinator(
            dependencies: try services.makeSessionDependencies(directories: directories),
            models: productionModels
        )
    }

    private static func makeAudioImporter(
        services: AppServiceGraph,
        directories: AppDirectories
    ) -> any AudioImporting {
        ImportedAudioTranscriber { url in
            LiveSessionCoordinator(
                dependencies: try services.makeSessionDependencies(
                    directories: directories,
                    capture: FileAudioCaptureProvider(url: url)
                ),
                models: productionModels,
                sessionKind: .importedAudio,
                sessionTitle: url.deletingPathExtension().lastPathComponent
            )
        }
    }

    private static var productionModels: SessionModelDescriptors {
        SessionModelDescriptors(
            speechRecognition: ProductionModelCatalog.qwenDescriptor,
            translation: ProductionModelCatalog.translationDescriptor
        )
    }

    private static func recoverInterruptedRecordings(services: AppServiceGraph) async {
        guard let sessions = try? await services.transcripts.recentSessions(limit: 10_000) else {
            return
        }
        for session in sessions {
            _ = try? await services.recordings.repairInterruptedRecording(sessionID: session.id)
        }
    }

    private static func makeRemoteServices(
        controller: LiveSessionCoordinator,
        settings: any SettingsStore
    ) -> RemoteServices {
        let sharing = RemoteSharingSwitch()
        let pairing = PairingRegistry()
        let projection = RemoteProjectionStore()
        let mutationTarget = LiveSessionRemoteMutationTarget(
            controller: controller,
            settings: settings
        )
        let commands = RevisionCheckedRemoteCommandHandler(
            revisionReader: ProjectionRevisionReader(projection: projection),
            sharing: sharing,
            target: mutationTarget
        )
        let transport = makeRemoteTransport(
            sharing: sharing,
            pairing: pairing,
            projection: projection,
            commands: commands
        )
        let configuration = RemoteTransportConfiguration(
            advertisedHostName: LocalNetworkHostName.value,
            bonjour: BonjourServiceDescriptor().descriptor()
        )
        return RemoteServices(
            sharingFeature: LocalNetworkSharingFeature(
                sharing: sharing,
                pairing: pairing,
                transport: transport,
                configuration: configuration
            ),
            projectionAdapter: LiveSessionProjectionAdapter(
                controller: controller,
                projection: projection
            )
        )
    }

    private static func makeRemoteTransport(
        sharing: RemoteSharingSwitch,
        pairing: PairingRegistry,
        projection: RemoteProjectionStore,
        commands: RevisionCheckedRemoteCommandHandler
    ) -> NWRemoteTransportServer {
        NWRemoteTransportServer(
            sharing: sharing,
            pairing: pairing,
            pairingManager: pairing,
            projection: projection,
            commands: commands,
            assets: BundledRemoteWebAssetProvider()
        )
    }
}
