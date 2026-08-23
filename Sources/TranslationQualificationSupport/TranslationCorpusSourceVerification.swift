import Foundation

extension TranslationQualificationCorpusLoader {
    static func verifyCorpusFiles(
        _ manifest: TranslationQualificationManifest,
        root: URL,
        manifestURL: URL
    ) throws {
        let provenance = manifest.provenance
        _ = try verifyLocal(
            provenance.parentCorpusManifestPath,
            expected: provenance.parentCorpusManifestSHA256,
            label: "parent corpus",
            root: root
        )
        try verifyProvenanceScripts(
            provenance,
            directory: manifestURL.deletingLastPathComponent(),
            root: root
        )
        for source in manifest.sources {
            try verifySource(source, root: root)
        }
        for candidate in manifest.candidateSources {
            for file in candidate.localFiles ?? [] {
                _ = try verifyLocal(file.path, expected: file.sha256, label: "candidate", root: root)
            }
        }
    }

    private static func verifySource(
        _ source: TranslationQualificationSource,
        root: URL
    ) throws {
        _ = try verifyLocal(
            source.audioLocalPath,
            expected: source.audioSHA256,
            label: "audio",
            root: root
        )
        _ = try verifyLocal(
            source.referenceLocalPath,
            expected: source.referenceSHA256,
            label: "reference",
            root: root
        )
        _ = try verifyLocal(
            source.extractedTextLocalPath,
            expected: source.extractedTextSHA256,
            label: "extracted text",
            root: root
        )
    }

    private static func verifyProvenanceScripts(
        _ provenance: TranslationQualificationProvenance,
        directory: URL,
        root: URL
    ) throws {
        let files = [
            ("build_bilingual_sermon_goldens.py", provenance.builderSHA256, "builder"),
            ("bilingual_golden_config.py", provenance.configSHA256, "config"),
            ("candidate_sources.py", provenance.candidateConfigSHA256, "candidate config"),
            ("corpus_build_support.py", provenance.supportSHA256, "support"),
        ]
        for (name, hash, label) in files {
            let url = try checkedURL(directory.appendingPathComponent(name), root: root)
            _ = try verifyFile(url, expected: hash, label: label)
        }
    }

    private static func verifyLocal(
        _ path: String,
        expected: String,
        label: String,
        root: URL
    ) throws -> String {
        try verifyFile(try localURL(path, root: root), expected: expected, label: label)
    }
}
