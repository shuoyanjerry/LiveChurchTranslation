import Foundation

public struct TranslationQualificationCorpus: Sendable {
    public let manifest: TranslationQualificationManifest
    public let manifestSHA256: String
    public let schemaSHA256: String

    public init(
        manifest: TranslationQualificationManifest,
        manifestSHA256: String,
        schemaSHA256: String
    ) {
        self.manifest = manifest
        self.manifestSHA256 = manifestSHA256
        self.schemaSHA256 = schemaSHA256
    }
}

public enum TranslationQualificationCorpusLoader {
    public static func load(
        manifestURL: URL,
        workspaceRoot: URL,
        expectedManifestSHA256: String,
        expectedSchemaSHA256: String
    ) throws -> TranslationQualificationCorpus {
        let manifestData: Data
        do {
            manifestData = try Data(contentsOf: manifestURL)
        } catch {
            throw TranslationQualificationError.missingFile("qualification manifest")
        }
        let manifestHash = TranslationQualificationSHA256.hash(data: manifestData)
        try verify(
            actual: manifestHash,
            expected: expectedManifestSHA256,
            label: "manifest"
        )
        let manifest = try TranslationQualificationManifestDecoder.decode(manifestData)
        try TranslationManifestValidator.validate(manifest)
        let root = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL
        let schemaURL = try localURL(manifest.schemaPath, root: root)
        let schemaHash = try verifyFile(
            schemaURL,
            expected: expectedSchemaSHA256,
            label: "schema"
        )
        try verifyCorpusFiles(manifest, root: root, manifestURL: manifestURL)
        return TranslationQualificationCorpus(
            manifest: manifest,
            manifestSHA256: manifestHash,
            schemaSHA256: schemaHash
        )
    }

    static func verifyFile(_ url: URL, expected: String, label: String) throws -> String {
        let actual = try TranslationQualificationSHA256.hash(fileAt: url)
        try verify(actual: actual, expected: expected, label: label)
        return actual
    }

    private static func verify(actual: String, expected: String, label: String) throws {
        guard actual == expected else {
            throw TranslationQualificationError.hashMismatch(
                label: label,
                expected: expected,
                actual: actual
            )
        }
    }

    static func localURL(_ path: String, root: URL) throws -> URL {
        guard !path.isEmpty, !path.hasPrefix("/") else {
            throw TranslationQualificationError.unsafePath("qualification path must be relative")
        }
        return try checkedURL(root.appendingPathComponent(path), root: root)
    }

    static func checkedURL(_ url: URL, root: URL) throws -> URL {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard resolved.path == root.path || resolved.path.hasPrefix(prefix) else {
            throw TranslationQualificationError.unsafePath("qualification path leaves workspace")
        }
        return resolved
    }
}
