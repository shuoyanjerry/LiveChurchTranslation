/// A frozen, provider-neutral manifest for reproducible ASR qualification.
public struct ASRQualificationManifestV2: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let corpusID: String
    public let provenance: ASRQualificationProvenanceV2
    public let clips: [ASRQualificationClipV2]

    public init(
        schemaVersion: Int,
        corpusID: String,
        provenance: ASRQualificationProvenanceV2,
        clips: [ASRQualificationClipV2]
    ) {
        self.schemaVersion = schemaVersion
        self.corpusID = corpusID
        self.provenance = provenance
        self.clips = clips
    }
}

/// Immutable identities for every upstream input used to freeze this manifest.
public struct ASRQualificationProvenanceV2: Codable, Equatable, Sendable {
    public let sourceVADReportSHA256: String
    public let sourceVADStrategy: String
    public let sourceVADConfigurationSHA256: String
    public let sourceReferenceManifestSHA256: String
    public let sourceCorpusManifestSHA256: String
    public let generatorRevision: String

    public init(
        sourceVADReportSHA256: String,
        sourceVADStrategy: String,
        sourceVADConfigurationSHA256: String,
        sourceReferenceManifestSHA256: String,
        sourceCorpusManifestSHA256: String,
        generatorRevision: String
    ) {
        self.sourceVADReportSHA256 = sourceVADReportSHA256
        self.sourceVADStrategy = sourceVADStrategy
        self.sourceVADConfigurationSHA256 = sourceVADConfigurationSHA256
        self.sourceReferenceManifestSHA256 = sourceReferenceManifestSHA256
        self.sourceCorpusManifestSHA256 = sourceCorpusManifestSHA256
        self.generatorRevision = generatorRevision
    }
}

/// Immutable source-audio identity and its absolute ASR segment definitions.
public struct ASRQualificationClipV2: Codable, Equatable, Sendable {
    public let id: String
    public let audioSHA256: String
    public let sampleRate: Int
    public let totalSamples: Int
    public let referenceSHA256: String
    public let allowsHypothesisEdgeInsertions: Bool
    public let segments: [ASRQualificationSegmentV2]

    public init(
        id: String,
        audioSHA256: String,
        sampleRate: Int,
        totalSamples: Int,
        referenceSHA256: String,
        allowsHypothesisEdgeInsertions: Bool,
        segments: [ASRQualificationSegmentV2]
    ) {
        self.id = id
        self.audioSHA256 = audioSHA256
        self.sampleRate = sampleRate
        self.totalSamples = totalSamples
        self.referenceSHA256 = referenceSHA256
        self.allowsHypothesisEdgeInsertions = allowsHypothesisEdgeInsertions
        self.segments = segments
    }
}

/// One exact model-input interval on the source clip's absolute sample timeline.
public struct ASRQualificationSegmentV2: Codable, Equatable, Sendable {
    public let sequence: Int
    public let startSample: Int
    public let endSample: Int
    public let validSampleCount: Int
    public let syntheticPaddingSamples: Int
    public let endReason: String
    public let pcmSHA256: String

    public init(
        sequence: Int,
        startSample: Int,
        endSample: Int,
        validSampleCount: Int,
        syntheticPaddingSamples: Int,
        endReason: String,
        pcmSHA256: String
    ) {
        self.sequence = sequence
        self.startSample = startSample
        self.endSample = endSample
        self.validSampleCount = validSampleCount
        self.syntheticPaddingSamples = syntheticPaddingSamples
        self.endReason = endReason
        self.pcmSHA256 = pcmSHA256
    }
}
