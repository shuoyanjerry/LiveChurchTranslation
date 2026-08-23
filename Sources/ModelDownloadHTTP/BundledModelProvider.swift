import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI

/// Read-only provider for release models sealed inside the application bundle.
public actor BundledModelProvider: ModelDownloadProvider {
    private let manifests: [ModelID: ModelDownloadManifest]
    private let rootDirectory: URL
    private let runtimeReporter: any ModelRuntimeReporting
    private let verifier = ArtifactVerifier()
    private var verifiedLocations: [ModelID: URL] = [:]

    public init(
        manifests: [ModelDownloadManifest],
        rootDirectory: URL,
        runtimeReporter: any ModelRuntimeReporting
    ) throws {
        guard rootDirectory.isFileURL, !rootDirectory.path.isEmpty, rootDirectory.path != "/" else {
            throw BundledModelError.invalidRoot
        }
        self.manifests = try ModelManifestIndex(manifests: manifests).manifests
        self.rootDirectory = rootDirectory.standardizedFileURL
        self.runtimeReporter = runtimeReporter
    }

    public func ensureAvailable(_ descriptor: ModelDescriptor) async throws -> URL {
        if let verified = verifiedLocations[descriptor.id] { return verified }
        guard let manifest = manifests[descriptor.id], manifest.descriptor == descriptor else {
            try await fail(descriptor, with: .manifestMismatch)
        }
        do {
            let location = try await verify(manifest)
            verifiedLocations[descriptor.id] = location
            await runtimeReporter.setState(.available(location: location), for: descriptor)
            return location
        } catch is CancellationError {
            throw ModelDownloadError.cancelled
        } catch let error as BundledModelError {
            try await fail(descriptor, with: error)
        } catch {
            try await fail(descriptor, with: .unreadableBundle)
        }
    }

    public func cancelDownload(for _: ModelID) async {}

    private func verify(_ manifest: ModelDownloadManifest) async throws -> URL {
        try Task.checkCancellation()
        let modelRoot = rootDirectory.appending(
            path: manifest.installDirectoryName,
            directoryHint: .isDirectory
        )
        try requireDirectory(modelRoot)
        guard modelRoot.resolvingSymlinksInPath().standardizedFileURL == modelRoot.standardizedFileURL
        else {
            throw BundledModelError.unreadableBundle
        }
        for artifact in manifest.artifacts {
            try Task.checkCancellation()
            let url = modelRoot.appending(path: artifact.relativePath, directoryHint: .notDirectory)
            guard url.resolvingSymlinksInPath().standardizedFileURL == url.standardizedFileURL
            else {
                throw BundledModelError.artifactMismatch(artifact.relativePath)
            }
            guard try await verifier.isValid(url, artifact: artifact) else {
                throw BundledModelError.artifactMismatch(artifact.relativePath)
            }
        }
        switch manifest.result {
        case .directory:
            return modelRoot
        case .file(let relativePath):
            return modelRoot.appending(path: relativePath, directoryHint: .notDirectory)
        }
    }

    private func requireDirectory(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw BundledModelError.unreadableBundle
        }
    }

    private func fail(
        _ descriptor: ModelDescriptor,
        with error: BundledModelError
    ) async throws -> Never {
        await runtimeReporter.setState(
            .failed(message: error.localizedDescription),
            for: descriptor
        )
        throw error
    }
}

public enum BundledModelError: LocalizedError, ModelPreparationUserFacingError, Equatable, Sendable {
    case invalidRoot
    case manifestMismatch
    case artifactMismatch(String)
    case unreadableBundle

    public var errorDescription: String? {
        modelPreparationMessage
    }

    public var modelPreparationMessage: String {
        switch self {
        case .invalidRoot:
            "应用内置模型目录无效。请重新安装应用。"
        case .manifestMismatch:
            "应用内置模型与当前版本不匹配。请重新下载安装包。"
        case .artifactMismatch(let path):
            "应用内置模型文件 \(path) 未通过完整性校验。请重新安装应用。"
        case .unreadableBundle:
            "无法读取应用内置模型。请将应用移到“应用程序”文件夹后重新打开。"
        }
    }
}
