import Foundation

struct ScriptureLlamaRuntimeSnapshot: Sendable {
    let helperSHA256: String
    let bundleSHA256: String
}

enum ScriptureLlamaRuntimeIdentity {
    static func verify(
        helperURL: URL,
        workspaceRoot: URL
    ) throws -> ScriptureLlamaRuntimeSnapshot {
        guard helperURL.lastPathComponent == "llama-server" else {
            throw mismatch
        }
        let manifestURL = workspaceRoot.appendingPathComponent(
            "Packaging/LlamaRuntime.sha256"
        )
        guard
            try QwenQualificationHashing.sha256(contentsOf: manifestURL)
                == manifestSHA256
        else { throw mismatch }
        let entries = try parseManifest(at: manifestURL)
        let directory = helperURL.deletingLastPathComponent().standardizedFileURL
        try requireExactFileSet(entries: entries, directory: directory)
        let verified = try entries.map { entry in
            try verify(entry, directory: directory)
        }
        try verifyArchiveMarker(directory: directory)
        guard let helper = verified.first(where: { $0.name == "llama-server" }) else {
            throw mismatch
        }
        return ScriptureLlamaRuntimeSnapshot(
            helperSHA256: helper.sha256,
            bundleSHA256: try ScriptureRuntimeBundleHasher.hash(verified)
        )
    }

    private static func parseManifest(at url: URL) throws -> [ScriptureRuntimeFile] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw mismatch }
        let entries = try text.split(whereSeparator: \.isNewline).map { line in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count == 2 else { throw mismatch }
            let sha = String(fields[0])
            let name = String(fields[1])
            guard isSHA256(sha), validFilename(name) else { throw mismatch }
            return ScriptureRuntimeFile(name: name, sha256: sha)
        }
        guard entries.count == expectedEntryCount,
            Set(entries.map(\.name)).count == entries.count
        else { throw mismatch }
        return entries
    }

    private static func requireExactFileSet(
        entries: [ScriptureRuntimeFile],
        directory: URL
    ) throws {
        let actual = try Set(FileManager.default.contentsOfDirectory(atPath: directory.path))
        let expected = Set(entries.map(\.name)).union([archiveMarker])
        guard actual == expected else { throw mismatch }
    }

    private static func verify(
        _ entry: ScriptureRuntimeFile,
        directory: URL
    ) throws -> ScriptureVerifiedRuntimeFile {
        let url = directory.appendingPathComponent(entry.name)
        let before = try regularFileSize(url)
        let actual = try QwenQualificationHashing.sha256(contentsOf: url)
        let after = try regularFileSize(url)
        guard before == after, actual == entry.sha256 else { throw mismatch }
        return ScriptureVerifiedRuntimeFile(
            name: entry.name,
            byteCount: before,
            sha256: actual
        )
    }

    private static func verifyArchiveMarker(directory: URL) throws {
        let url = directory.appendingPathComponent(archiveMarker)
        guard try regularFileSize(url) > 0,
            try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines) == archiveSHA256
        else { throw mismatch }
    }

    private static func regularFileSize(_ url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [
            .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
            let size = values.fileSize, size > 0
        else { throw mismatch }
        return Int64(size)
    }

    private static func validFilename(_ value: String) -> Bool {
        !value.isEmpty && !value.contains("/") && value != "." && value != ".."
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static let expectedEntryCount = 12
    private static let archiveMarker = ".complete-b10549"
    private static let archiveSHA256 =
        "71e4b31afb020d6b71894eb8d1f2c0693038aec3f41f672f9fafb5055c8f2226"
    private static let manifestSHA256 =
        "5d90e8abb5022535a43a8ddc1ef73a177c9a79fba599ab9ade5b996bde52ed50"
    private static let mismatch =
        ScriptureModelQualificationError.modelIdentityMismatch("llama-runtime-bundle")
}

struct ScriptureRuntimeFile {
    let name: String
    let sha256: String
}

struct ScriptureVerifiedRuntimeFile {
    let name: String
    let byteCount: Int64
    let sha256: String
}
