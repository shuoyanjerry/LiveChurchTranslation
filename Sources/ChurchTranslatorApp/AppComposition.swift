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
import SettingsAPI

struct AppSceneDependencies {
    let viewModel: LiveReaderViewModel
    let sharingFeature: any LocalSharingFeature
    let projectionAdapter: LiveSessionProjectionAdapter
}

@MainActor
enum AppComposition {
    static func build() throws -> AppSceneDependencies {
        let directories = try AppDirectories.production()
        let services = try AppServiceGraph(directories: directories)
        let controller = LiveSessionCoordinator(
            dependencies: try services.makeSessionDependencies(directories: directories),
            models: SessionModelDescriptors(
                speechRecognition: ProductionModelCatalog.qwenDescriptor,
                translation: ProductionModelCatalog.translationDescriptor
            )
        )
        let viewModel = LiveReaderViewModel(
            controller: controller,
            capture: services.capture,
            glossary: services.glossary,
            settingsStore: services.settings
        )
        let remote = makeRemoteServices(controller: controller, settings: services.settings)
        Task { await remote.projectionAdapter.start() }
        return AppSceneDependencies(
            viewModel: viewModel,
            sharingFeature: remote.sharingFeature,
            projectionAdapter: remote.projectionAdapter
        )
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
