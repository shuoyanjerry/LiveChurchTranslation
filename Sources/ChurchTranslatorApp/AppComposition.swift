import AudioImportAPI
import LiveReader
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
import SessionManagementAPI
import SettingsAPI

struct AppSceneDependencies {
    let controller: LiveSessionCoordinator
    let viewModel: LiveReaderViewModel
    let libraryViewModel: SessionLibraryViewModel
    let permissionCoordinator: MicrophonePermissionCoordinator
    let sharingFeature: any LocalSharingFeature
    let projectionAdapter: LiveSessionProjectionAdapter
    let audioImporter: any AudioImporting
    let modelPreparations: [any ModelPreparationController]
}

@MainActor
enum AppComposition {
    static func build() throws -> AppSceneDependencies {
        let directories = try AppDirectories.production()
        let models = productionModels
        let services = try AppServiceGraph(directories: directories, models: models)
        let controller = try makeController(services: services, directories: directories)
        return makeSceneDependencies(
            services: services,
            controller: controller,
            directories: directories
        )
    }

    private static func makeController(
        services: AppServiceGraph,
        directories: AppDirectories
    ) throws -> LiveSessionCoordinator {
        LiveSessionCoordinator(
            dependencies: try services.makeSessionDependencies(directories: directories),
            models: productionModels,
            modelPreparation: services.modelPreparation
        )
    }

    static func makeRemoteServices(
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
