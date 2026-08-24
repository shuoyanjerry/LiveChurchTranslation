import Foundation

/// A non-interactive relocation probe used only by release packaging.
///
/// It proves that the copied application resolves its executable helper and every
/// bundled model from its own bundle. It deliberately performs no network access,
/// inference, permission request, or user-interface work.
public enum InstallationProbe {
    public static func run(bundle: Bundle = .main) -> Bool {
        guard bundle.bundleIdentifier == "com.shuoyan.LiveChurchTranslation",
            let resources = bundle.resourceURL,
            isDirectory(resources),
            requiredMetadataExists(in: resources),
            helperExists(in: bundle)
        else {
            return false
        }

        do {
            return try modelsExist(in: resources)
        } catch {
            return false
        }
    }

    private static func requiredMetadataExists(in resources: URL) -> Bool {
        let files = [
            "PRIVACY.md",
            "PrivacyInfo.xcprivacy",
            "THIRD_PARTY_NOTICES.md",
            "llama.cpp-LICENSE",
        ]
        guard files.allSatisfy({ isRegularFile(resources.appending(path: $0)) }) else {
            return false
        }
        return isDirectory(resources.appending(path: "Licenses", directoryHint: .isDirectory))
    }

    private static func helperExists(in bundle: Bundle) -> Bool {
        let helper = bundle.bundleURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "MacOS", directoryHint: .isDirectory)
            .appending(path: "llama-server", directoryHint: .notDirectory)
        return isRegularFile(helper) && FileManager.default.isExecutableFile(atPath: helper.path)
    }

    private static func modelsExist(in resources: URL) throws -> Bool {
        let root = resources.appending(path: "Models", directoryHint: .isDirectory)
        guard isDirectory(root) else { return false }

        for manifest in try ProductionModelCatalog.manifests() {
            let modelRoot = root.appending(
                path: manifest.installDirectoryName,
                directoryHint: .isDirectory
            )
            guard isDirectory(modelRoot) else { return false }
            for artifact in manifest.artifacts {
                let file = modelRoot.appending(
                    path: artifact.relativePath,
                    directoryHint: .notDirectory
                )
                let values = try file.resourceValues(
                    forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
                )
                guard values.isRegularFile == true,
                    values.isSymbolicLink != true,
                    values.fileSize.map(Int64.init) == artifact.expectedBytes
                else {
                    return false
                }
            }
        }
        return true
    }

    private static func isDirectory(_ url: URL) -> Bool {
        guard
            let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
        else {
            return false
        }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        guard
            let values = try? url.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )
        else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }
}
