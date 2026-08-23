import Foundation

struct ScriptureQualificationFileVerifier {
    let root: URL

    init(privateRoot: URL) throws {
        let standardized = privateRoot.standardizedFileURL
        try Self.requirePrivateRootShape(standardized)
        let values = try Self.values(standardized, label: "private root")
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw ScriptureQualificationError.unsafePath("private root must be a real directory")
        }
        try Self.requireOwnerOnlyPermissions(standardized, label: "private root")
        root = standardized.resolvingSymlinksInPath()
        guard root == standardized else {
            throw ScriptureQualificationError.unsafePath("private root must not contain symlinks")
        }
    }

    func file(
        relativePath: String,
        expectedSHA256: String,
        label: String,
        maximumBytes: Int
    ) throws -> URL {
        try ScriptureQualificationScalarRules.requireRelativePath(relativePath, label: label)
        return try file(
            at: root.appendingPathComponent(relativePath),
            expectedSHA256: expectedSHA256,
            label: label,
            maximumBytes: maximumBytes
        )
    }

    func file(
        at url: URL,
        expectedSHA256: String,
        label: String,
        maximumBytes: Int
    ) throws -> URL {
        try ScriptureQualificationScalarRules.requireHash(expectedSHA256, label: label)
        let standardized = url.standardizedFileURL
        try requireContained(standardized)
        try rejectSymlinkComponents(to: standardized)
        let values = try Self.values(standardized, label: label)
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ScriptureQualificationError.invalidFile("\(label) must be a regular file")
        }
        guard let size = values.fileSize, size > 0 else {
            throw ScriptureQualificationError.invalidFile("\(label) must not be empty")
        }
        guard size <= maximumBytes else {
            throw ScriptureQualificationError.fileTooLarge(label)
        }
        try Self.requireOwnerOnlyPermissions(standardized, label: label)
        let resolved = standardized.resolvingSymlinksInPath()
        try requireContained(resolved)
        let actual = try ScriptureQualificationSHA256.hash(fileAt: resolved)
        guard actual == expectedSHA256 else {
            throw ScriptureQualificationError.hashMismatch(
                label: label,
                expected: expectedSHA256,
                actual: actual
            )
        }
        return resolved
    }

    private func requireContained(_ url: URL) throws {
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path == root.path || url.path.hasPrefix(prefix) else {
            throw ScriptureQualificationError.unsafePath("file leaves private root")
        }
    }

    private func rejectSymlinkComponents(to url: URL) throws {
        let relative = String(url.path.dropFirst(root.path.count)).trimmingCharacters(
            in: CharacterSet(charactersIn: "/"))
        var cursor = root
        for component in relative.split(separator: "/") {
            cursor.appendPathComponent(String(component))
            let values = try Self.values(cursor, label: "private-corpus path")
            guard values.isSymbolicLink != true else {
                throw ScriptureQualificationError.unsafePath("symlinks are forbidden")
            }
            if cursor != url, values.isDirectory == true {
                try Self.requireOwnerOnlyPermissions(cursor, label: "private-corpus directory")
            }
        }
    }

    private static func requirePrivateRootShape(_ url: URL) throws {
        let components = url.pathComponents
        guard let artifacts = components.lastIndex(of: ".artifacts") else {
            throw ScriptureQualificationError.unsafePath("root must be below .artifacts")
        }
        let qualification = components.index(after: artifacts)
        guard qualification < components.endIndex,
            components[qualification] == "scripture-qualification",
            components.index(after: qualification) < components.endIndex
        else {
            throw ScriptureQualificationError.unsafePath(
                "root must be a corpus directory below .artifacts/scripture-qualification"
            )
        }
    }

    private static func values(_ url: URL, label: String) throws -> URLResourceValues {
        do {
            return try url.resourceValues(forKeys: [
                .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
            ])
        } catch {
            throw ScriptureQualificationError.missingFile(label)
        }
    }

    private static func requireOwnerOnlyPermissions(_ url: URL, label: String) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let permissions = attributes[.posixPermissions] as? NSNumber,
            permissions.intValue & 0o077 == 0
        else {
            throw ScriptureQualificationError.invalidFile("\(label) permissions must be owner-only")
        }
    }
}
