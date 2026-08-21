import Foundation
import ModelDownloadAPI

struct SecureInstallLayout: Sendable {
    let installRoot: URL
    let outputURL: URL
    private let baseRoot: URL

    init(rootDirectory: URL, manifest: ModelDownloadManifest) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
        baseRoot = rootDirectory.resolvingSymlinksInPath().standardizedFileURL
        installRoot =
            baseRoot
            .appendingPathComponent(manifest.installDirectoryName, isDirectory: true)
            .standardizedFileURL
        try Self.requireContained(installRoot, by: baseRoot)
        outputURL = try Self.makeOutputURL(manifest.result, installRoot: installRoot)
    }

    func prepare(for artifact: ModelArtifactManifest) throws -> (final: URL, part: URL) {
        try rejectSymlink(at: installRoot)
        try FileManager.default.createDirectory(
            at: installRoot,
            withIntermediateDirectories: true
        )
        let final = try artifactURL(relativePath: artifact.relativePath)
        try prepareParents(of: final)
        let part =
            final
            .deletingLastPathComponent()
            .appendingPathComponent(final.lastPathComponent + ".part")
        try Self.requireContained(part, by: installRoot)
        return (final, part)
    }

    func artifactURL(relativePath: String) throws -> URL {
        let candidate = relativePath.split(separator: "/").reduce(installRoot) {
            $0.appendingPathComponent(String($1))
        }.standardizedFileURL
        try Self.requireContained(candidate, by: installRoot)
        return candidate
    }

    func removeReplaceableItem(at url: URL) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return }
        let type = try manager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
        guard type == .typeRegular || type == .typeSymbolicLink else {
            throw ModelDownloadError.invalidArtifact
        }
        try manager.removeItem(at: url)
    }

    func commit(part: URL, final: URL) throws {
        guard !FileManager.default.fileExists(atPath: final.path) else {
            throw ModelDownloadError.invalidArtifact
        }
        try FileManager.default.moveItem(at: part, to: final)
    }

    private func prepareParents(of file: URL) throws {
        let relative = file.deletingLastPathComponent().path
            .dropFirst(installRoot.path.count)
        var cursor = installRoot
        for component in relative.split(separator: "/") {
            cursor.appendPathComponent(String(component), isDirectory: true)
            if FileManager.default.fileExists(atPath: cursor.path) {
                try rejectSymlink(at: cursor)
            } else {
                try FileManager.default.createDirectory(
                    at: cursor,
                    withIntermediateDirectories: false
                )
            }
        }
    }

    private func rejectSymlink(at url: URL) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return }
        let type = try manager.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
        guard type != .typeSymbolicLink else {
            throw ModelDownloadError.invalidArtifact
        }
        guard type == .typeDirectory else {
            throw ModelDownloadError.invalidArtifact
        }
    }

    private static func makeOutputURL(
        _ result: ModelInstallResult,
        installRoot: URL
    ) throws -> URL {
        switch result {
        case .directory:
            return installRoot
        case .file(let path):
            let candidate = path.split(separator: "/").reduce(installRoot) {
                $0.appendingPathComponent(String($1))
            }.standardizedFileURL
            try requireContained(candidate, by: installRoot)
            return candidate
        }
    }

    private static func requireContained(_ child: URL, by parent: URL) throws {
        let root = parent.standardizedFileURL.path
        let path = child.standardizedFileURL.path
        guard path.hasPrefix(root + "/") else {
            throw ModelDownloadError.invalidArtifact
        }
    }
}
