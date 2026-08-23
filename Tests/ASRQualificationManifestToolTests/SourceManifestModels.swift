struct CorpusManifest: Decodable {
    let schemaVersion: Int
    let corpusID: String
    let description: String
    let license: CorpusLicense
    let referenceBundleSHA256: String
    let clips: [CorpusClip]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case corpusID = "corpus_id"
        case description, license, clips
        case referenceBundleSHA256 = "reference_bundle_sha256"
    }
}

struct CorpusLicense: Decodable {
    let audio: String
    let audioURL: String
    let reference: String
    let referenceURL: String

    enum CodingKeys: String, CodingKey {
        case audio, reference
        case audioURL = "audio_url"
        case referenceURL = "reference_url"
    }
}

struct CorpusClip: Decodable {
    let id: String
    let audioPath: String
    let durationMilliseconds: Double
    let referenceText: String
    let referenceSegments: [String]
    let focus: [String]
    let sourcePage: String
    let audioURL: String
    let audioDownloadSHA256: String
    let referenceEntries: [String]

    enum CodingKeys: String, CodingKey {
        case id, focus
        case audioPath = "audio_path"
        case durationMilliseconds = "duration_ms"
        case referenceText = "reference_text"
        case referenceSegments = "reference_segments"
        case sourcePage = "source_page"
        case audioURL = "audio_url"
        case audioDownloadSHA256 = "audio_download_sha256"
        case referenceEntries = "reference_entries"
    }
}

struct ReferenceManifest: Decodable {
    let schemaVersion: Int
    let corpusID: String
    let boundaryCollarMilliseconds: Double
    let latencyReferenceKind: String
    let pronounReferenceKind: String
    let qualityGates: EmptyObject
    let clips: [ReferenceClip]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case corpusID = "corpus_id"
        case boundaryCollarMilliseconds = "boundary_collar_ms"
        case latencyReferenceKind = "latency_reference_kind"
        case pronounReferenceKind = "pronoun_reference_kind"
        case qualityGates = "quality_gates"
        case clips
    }
}

struct ReferenceClip: Decodable {
    let id: String
    let durationMilliseconds: Double
    let referenceText: String
    let referenceSegments: [String]
    let ignoresHypothesisEdges: Bool
    let pronouns: [ReferencePronoun]
    let translationChecks: [EmptyObject]

    enum CodingKeys: String, CodingKey {
        case id, pronouns
        case durationMilliseconds = "duration_ms"
        case referenceText = "reference_text"
        case referenceSegments = "reference_segments"
        case ignoresHypothesisEdges = "asr_ignore_hypothesis_edges"
        case translationChecks = "translation_checks"
    }
}

struct ReferencePronoun: Decodable {
    let id: String
    let value: String
    let resolvable: Bool
}

struct EmptyObject: Decodable {}
