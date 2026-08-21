import Foundation
import ModelRuntimeAPI

struct ModelManifestIndex {
    let manifests: [ModelID: ModelDownloadManifest]

    init(manifests source: [ModelDownloadManifest]) throws {
        var indexed: [ModelID: ModelDownloadManifest] = [:]
        var installationNames: Set<String> = []
        for manifest in source {
            try Self.insert(manifest, into: &indexed)
            let name = manifest.installDirectoryName.lowercased()
            guard installationNames.insert(name).inserted else {
                throw ModelDownloadConfigurationError.duplicateInstallDirectory(
                    manifest.installDirectoryName
                )
            }
        }
        manifests = indexed
    }

    private static func insert(
        _ manifest: ModelDownloadManifest,
        into index: inout [ModelID: ModelDownloadManifest]
    ) throws {
        guard index.updateValue(manifest, forKey: manifest.descriptor.id) == nil else {
            throw ModelDownloadConfigurationError.duplicateManifest(
                manifest.descriptor.id
            )
        }
    }
}

enum ModelDownloadRootValidator {
    static func validate(_ rootDirectory: URL) throws {
        let path = rootDirectory.standardizedFileURL.path
        guard rootDirectory.isFileURL, !path.isEmpty, path != "/" else {
            throw ModelDownloadConfigurationError.invalidRootDirectory
        }
    }
}
