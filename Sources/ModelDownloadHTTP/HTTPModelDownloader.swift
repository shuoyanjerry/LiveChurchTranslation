import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI

/// Actor-isolated, manifest-driven local model installer.
///
/// Concurrent requests for the same model await one shared task. A verified file is
/// published only after exact byte-count and SHA-256 checks succeed.
public actor HTTPModelDownloader: ModelDownloadProvider {
    private let manifests: [ModelID: ModelDownloadManifest]
    private let installer: ModelInstaller
    private var activeDownloads: [ModelID: ActiveDownload] = [:]

    public init(
        manifests: [ModelDownloadManifest],
        rootDirectory: URL,
        transport: any ModelHTTPTransport = URLSessionModelHTTPTransport(),
        locationStore: any ModelLocationStore,
        runtimeReporter: any ModelRuntimeReporting
    ) throws {
        try self.init(
            manifests: manifests,
            rootDirectory: rootDirectory,
            transport: transport,
            locationStore: locationStore,
            runtimeReporter: runtimeReporter,
            diskCapacityProvider: VolumeModelDiskCapacityProvider(),
            diskSafetyMarginBytes: ModelDiskSpaceReservations.productionSafetyMarginBytes
        )
    }

    init(
        manifests: [ModelDownloadManifest],
        rootDirectory: URL,
        transport: any ModelHTTPTransport,
        locationStore: any ModelLocationStore,
        runtimeReporter: any ModelRuntimeReporting,
        diskCapacityProvider: any ModelDiskCapacityProviding,
        diskSafetyMarginBytes: Int64
    ) throws {
        try ModelDownloadRootValidator.validate(rootDirectory)
        self.manifests = try ModelManifestIndex(manifests: manifests).manifests
        let diskReservations = try ModelDiskSpaceReservations(
            rootDirectory: rootDirectory,
            capacityProvider: diskCapacityProvider,
            safetyMarginBytes: diskSafetyMarginBytes
        )
        installer = ModelInstaller(
            rootDirectory: rootDirectory,
            transport: transport,
            locationStore: locationStore,
            runtimeReporter: runtimeReporter,
            diskReservations: diskReservations
        )
    }

    public func ensureAvailable(_ descriptor: ModelDescriptor) async throws -> URL {
        guard let manifest = manifests[descriptor.id] else {
            let error = ModelDownloadError.downloadFailed(
                "No manifest is registered for \(descriptor.id.rawValue)."
            )
            await installer.runtimeReporter.setState(
                .failed(message: error.localizedDescription),
                for: descriptor
            )
            throw error
        }
        guard manifest.descriptor == descriptor else {
            await installer.runtimeReporter.setState(
                .failed(message: ModelDownloadError.invalidArtifact.localizedDescription),
                for: descriptor
            )
            throw ModelDownloadError.invalidArtifact
        }
        if let active = activeDownloads[descriptor.id] {
            return try await active.task.value
        }

        let token = UUID()
        let task = Task { [installer, manifest] in
            try await installer.install(manifest)
        }
        activeDownloads[descriptor.id] = ActiveDownload(token: token, task: task)
        do {
            let location = try await task.value
            removeDownload(for: descriptor.id, matching: token)
            return location
        } catch {
            removeDownload(for: descriptor.id, matching: token)
            throw error
        }
    }

    public func cancelDownload(for modelID: ModelID) async {
        guard let active = activeDownloads[modelID] else { return }
        active.task.cancel()
        _ = await active.task.result
        removeDownload(for: modelID, matching: active.token)
    }

    private func removeDownload(for modelID: ModelID, matching token: UUID) {
        guard activeDownloads[modelID]?.token == token else { return }
        activeDownloads[modelID] = nil
    }
}

/// Errors that make the downloader unsafe to construct.
public enum ModelDownloadConfigurationError: LocalizedError, Equatable, Sendable {
    case invalidRootDirectory
    case invalidDiskSafetyMargin
    case duplicateManifest(ModelID)
    case duplicateInstallDirectory(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRootDirectory: "The model download root must be a specific file URL."
        case .invalidDiskSafetyMargin: "The model disk safety margin cannot be negative."
        case .duplicateManifest(let id): "Multiple manifests use model ID \(id.rawValue)."
        case .duplicateInstallDirectory(let name):
            "Multiple manifests use installation directory \(name)."
        }
    }
}

private struct ActiveDownload: Sendable {
    let token: UUID
    let task: Task<URL, Error>
}
