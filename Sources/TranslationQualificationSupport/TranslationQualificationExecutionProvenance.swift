public struct TranslationQualificationArtifactDigest: Codable, Equatable, Sendable {
    public let byteCount: Int64
    public let sha256: String

    public init(byteCount: Int64, sha256: String) {
        self.byteCount = byteCount
        self.sha256 = sha256
    }
}

public struct TranslationQualificationBundleDigest: Codable, Equatable, Sendable {
    public let format: String
    public let entryCount: Int
    public let byteCount: Int64
    public let sha256: String

    public init(format: String, entryCount: Int, byteCount: Int64, sha256: String) {
        self.format = format
        self.entryCount = entryCount
        self.byteCount = byteCount
        self.sha256 = sha256
    }
}

public struct TranslationExecutionProvenance: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let bundleFormat = "qlr-framed-file-bundle-v1"

    public let version: Int
    public let buildConfiguration: String
    public let sourceBundle: TranslationQualificationBundleDigest
    public let testExecutable: TranslationQualificationArtifactDigest
    public let model: TranslationQualificationArtifactDigest
    public let helper: TranslationQualificationArtifactDigest
    public let runtimeBundle: TranslationQualificationBundleDigest
    public let configurationSHA256: String
    public let manifestSHA256: String
    public let corpusSchemaSHA256: String

    public init(
        version: Int = currentVersion,
        buildConfiguration: String,
        sourceBundle: TranslationQualificationBundleDigest,
        testExecutable: TranslationQualificationArtifactDigest,
        model: TranslationQualificationArtifactDigest,
        helper: TranslationQualificationArtifactDigest,
        runtimeBundle: TranslationQualificationBundleDigest,
        configurationSHA256: String,
        manifestSHA256: String,
        corpusSchemaSHA256: String
    ) {
        self.version = version
        self.buildConfiguration = buildConfiguration
        self.sourceBundle = sourceBundle
        self.testExecutable = testExecutable
        self.model = model
        self.helper = helper
        self.runtimeBundle = runtimeBundle
        self.configurationSHA256 = configurationSHA256
        self.manifestSHA256 = manifestSHA256
        self.corpusSchemaSHA256 = corpusSchemaSHA256
    }
}
