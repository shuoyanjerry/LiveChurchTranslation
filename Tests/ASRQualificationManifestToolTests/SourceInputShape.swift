import Foundation

enum SourceInputShape {
    static func validateCorpus(_ data: Data) throws {
        let root = try StrictJSONShape.rootObject(data, source: "corpus")
        try StrictJSONShape.exact(
            root,
            keys: [
                "schema_version", "corpus_id", "description", "license",
                "reference_bundle_sha256", "clips",
            ],
            path: "corpus"
        )
        try validateLicense(root["license"])
        let clips = try StrictJSONShape.array(root["clips"], path: "corpus.clips")
        for (index, value) in clips.enumerated() {
            try validateCorpusClip(value, path: "corpus.clips[\(index)]")
        }
    }

    static func validateReference(_ data: Data) throws {
        let root = try StrictJSONShape.rootObject(data, source: "reference")
        try StrictJSONShape.exact(
            root,
            keys: [
                "schema_version", "corpus_id", "boundary_collar_ms",
                "latency_reference_kind", "pronoun_reference_kind", "quality_gates", "clips",
            ],
            path: "reference"
        )
        let gates = try StrictJSONShape.object(root["quality_gates"], path: "reference.quality_gates")
        try StrictJSONShape.exact(gates, keys: [], path: "reference.quality_gates")
        let clips = try StrictJSONShape.array(root["clips"], path: "reference.clips")
        for (index, value) in clips.enumerated() {
            try validateReferenceClip(value, path: "reference.clips[\(index)]")
        }
    }

    private static func validateLicense(_ value: Any?) throws {
        let path = "corpus.license"
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: ["audio", "audio_url", "reference", "reference_url"],
            path: path
        )
    }

    private static func validateCorpusClip(_ value: Any, path: String) throws {
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: [
                "id", "audio_path", "duration_ms", "reference_text", "reference_segments",
                "focus", "source_page", "audio_url", "audio_download_sha256",
                "reference_entries",
            ],
            path: path
        )
    }

    private static func validateReferenceClip(_ value: Any, path: String) throws {
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: [
                "id", "duration_ms", "reference_text", "reference_segments",
                "asr_ignore_hypothesis_edges", "pronouns", "translation_checks",
            ],
            path: path
        )
        try validatePronouns(object["pronouns"], path: "\(path).pronouns")
        try validateEmptyObjects(
            object["translation_checks"],
            path: "\(path).translation_checks"
        )
    }

    private static func validatePronouns(_ value: Any?, path: String) throws {
        let pronouns = try StrictJSONShape.array(value, path: path)
        for (index, value) in pronouns.enumerated() {
            let itemPath = "\(path)[\(index)]"
            let object = try StrictJSONShape.object(value, path: itemPath)
            try StrictJSONShape.exact(
                object,
                keys: ["id", "value", "resolvable"],
                path: itemPath
            )
        }
    }

    private static func validateEmptyObjects(_ value: Any?, path: String) throws {
        let objects = try StrictJSONShape.array(value, path: path)
        for (index, value) in objects.enumerated() {
            let itemPath = "\(path)[\(index)]"
            let object = try StrictJSONShape.object(value, path: itemPath)
            try StrictJSONShape.exact(object, keys: [], path: itemPath)
        }
    }
}
