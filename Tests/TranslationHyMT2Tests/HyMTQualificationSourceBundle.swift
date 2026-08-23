import Foundation
import TranslationQualificationSupport

enum HyMTQualificationSourceBundle {
    static func capture(
        workspaceRoot: URL
    ) throws -> TranslationQualificationBundleDigest {
        let root = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL
        var inputs = try requiredRootFiles(root)
        for directory in recursiveRoots {
            inputs += try files(in: directory, root: root)
        }
        return try HyMTQualificationFileHasher.bundle(inputs)
    }

    private static func requiredRootFiles(_ root: URL) throws -> [HyMTQualificationFileInput] {
        try rootFiles.map { relativePath in
            let url = try checked(root.appendingPathComponent(relativePath), root: root)
            return HyMTQualificationFileInput(relativePath: relativePath, url: url)
        }
    }

    private static func files(
        in relativeDirectory: String,
        root: URL
    ) throws -> [HyMTQualificationFileInput] {
        let directory = try checked(root.appendingPathComponent(relativeDirectory), root: root)
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                options: []
            )
        else { throw invalid }
        var result: [HyMTQualificationFileInput] = []
        while let url = enumerator.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: [
                .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
            ])
            if values.isSymbolicLink == true { throw invalid }
            if excludedNames.contains(url.lastPathComponent) {
                if values.isDirectory == true { enumerator.skipDescendants() }
                continue
            }
            guard values.isRegularFile == true else { continue }
            let checkedURL = try checked(url, root: root)
            let relativePath = String(checkedURL.path.dropFirst(root.path.count + 1))
            result.append(HyMTQualificationFileInput(relativePath: relativePath, url: checkedURL))
        }
        return result
    }

    private static func checked(_ url: URL, root: URL) throws -> URL {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard resolved.path.hasPrefix(prefix) else { throw invalid }
        return resolved
    }

    private static let rootFiles = ["Package.swift", "Package.resolved"]
    private static let recursiveRoots = ["Sources", "Tests", "Scripts"]
    private static let excludedNames = Set([".artifacts", ".build", ".git"])
    private static let invalid = TranslationQualificationError.invalidReport(
        "qualification source bundle is missing, unsafe, or contains a symlink"
    )
}
