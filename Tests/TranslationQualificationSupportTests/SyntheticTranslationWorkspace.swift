import Foundation
import TranslationQualificationSupport

final class SyntheticTranslationWorkspace {
    let root: URL
    let manifestURL: URL
    let manifestSHA256: String
    let schemaSHA256: String
    let sourceAssetURL: URL

    init(requiresHumanReview: Bool = true) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let directory = root.appendingPathComponent(".artifacts/synthetic", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = try Self.makeFiles(in: directory)
        sourceAssetURL = files.source
        schemaSHA256 = try TranslationQualificationSHA256.hash(fileAt: files.schema)
        let manifest = SyntheticTranslationManifestFactory.make(
            hashes: files.hashes,
            requiresHumanReview: requiresHumanReview
        )
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys])
        manifestURL = try Self.write(data, named: "manifest.json", in: directory)
        manifestSHA256 = TranslationQualificationSHA256.hash(data: data)
    }

    private static func makeFiles(in directory: URL) throws -> SyntheticTranslationFiles {
        let schema = try write(Data(#"{"synthetic":true}"#.utf8), named: "schema.json", in: directory)
        let builderFiles = try makeBuilderFiles(in: directory)
        let source = try Self.write(
            Data("source-asset".utf8),
            named: "source.bin",
            in: directory
        )
        let hashes = try SyntheticTranslationHashes(
            parent: builderFiles.parent,
            builder: builderFiles.builder,
            config: builderFiles.config,
            candidate: builderFiles.candidate,
            support: builderFiles.support,
            source: source
        )
        return SyntheticTranslationFiles(schema: schema, source: source, hashes: hashes)
    }

    private static func makeBuilderFiles(in directory: URL) throws -> SyntheticBuilderFiles {
        let parent = try write(Data("parent".utf8), named: "parent.json", in: directory)
        let builder = try write(
            Data("builder".utf8),
            named: "build_bilingual_sermon_goldens.py",
            in: directory
        )
        let config = try write(
            Data("config".utf8),
            named: "bilingual_golden_config.py",
            in: directory
        )
        let candidate = try write(
            Data("candidate".utf8),
            named: "candidate_sources.py",
            in: directory
        )
        let support = try write(
            Data("support".utf8),
            named: "corpus_build_support.py",
            in: directory
        )
        return SyntheticBuilderFiles(
            parent: parent,
            builder: builder,
            config: config,
            candidate: candidate,
            support: support
        )
    }

    func load() throws -> TranslationQualificationCorpus {
        try TranslationQualificationCorpusLoader.load(
            manifestURL: manifestURL,
            workspaceRoot: root,
            expectedManifestSHA256: manifestSHA256,
            expectedSchemaSHA256: schemaSHA256
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private static func write(_ data: Data, named name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}

private struct SyntheticTranslationFiles {
    let schema: URL
    let source: URL
    let hashes: SyntheticTranslationHashes
}

private struct SyntheticBuilderFiles {
    let parent: URL
    let builder: URL
    let config: URL
    let candidate: URL
    let support: URL
}

struct SyntheticTranslationHashes {
    let parent: String
    let builder: String
    let config: String
    let candidate: String
    let support: String
    let source: String

    init(
        parent: URL,
        builder: URL,
        config: URL,
        candidate: URL,
        support: URL,
        source: URL
    ) throws {
        self.parent = try TranslationQualificationSHA256.hash(fileAt: parent)
        self.builder = try TranslationQualificationSHA256.hash(fileAt: builder)
        self.config = try TranslationQualificationSHA256.hash(fileAt: config)
        self.candidate = try TranslationQualificationSHA256.hash(fileAt: candidate)
        self.support = try TranslationQualificationSHA256.hash(fileAt: support)
        self.source = try TranslationQualificationSHA256.hash(fileAt: source)
    }
}
