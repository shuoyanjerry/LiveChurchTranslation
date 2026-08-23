public struct TranslationReleaseExpectation: Sendable {
    public let executionProvenance: TranslationExecutionProvenance
    public let corpus: TranslationQualificationCorpus
    public let provider: TranslationQualificationProvider
    public let environment: TranslationQualificationEnvironment
    public let attemptCount: Int
    public let attemptIdentitySHA256: String
    let trustedAttempts: [TranslationQualificationAttempt]

    public init(
        trustedExecutionProvenance: TranslationExecutionProvenance,
        corpus: TranslationQualificationCorpus,
        provider: TranslationQualificationProvider,
        environment: TranslationQualificationEnvironment,
        attempts: [TranslationQualificationAttempt]
    ) throws {
        try self.init(
            trustedExecutionProvenance: trustedExecutionProvenance,
            trustedCorpus: corpus,
            trustedProvider: provider,
            trustedEnvironment: environment,
            trustedAttempts: attempts,
            attemptCount: corpus.manifest.segments.count,
            attemptIdentitySHA256: TranslationAttemptIdentityDigest.hash(
                corpus.manifest.segments
            )
        )
    }

    public init(
        trustedExecutionProvenance: TranslationExecutionProvenance,
        trustedCorpus: TranslationQualificationCorpus,
        trustedProvider: TranslationQualificationProvider,
        trustedEnvironment: TranslationQualificationEnvironment,
        trustedAttempts: [TranslationQualificationAttempt],
        attemptCount: Int,
        attemptIdentitySHA256: String
    ) throws {
        try TranslationProvenanceValidator.validate(
            trustedExecutionProvenance,
            corpus: trustedCorpus,
            provider: trustedProvider
        )
        _ = try TranslationQualificationReportBuilder.build(
            generatedAt: "2001-01-01T00:00:00Z",
            corpus: trustedCorpus,
            provider: trustedProvider,
            environment: trustedEnvironment,
            executionProvenance: trustedExecutionProvenance,
            attempts: trustedAttempts
        )
        guard
            TranslationProvenanceValidator.isStructurallyValid(
                trustedExecutionProvenance
            ),
            attemptCount > 0,
            TranslationProvenanceValidator.isSHA(attemptIdentitySHA256)
        else {
            throw TranslationQualificationError.invalidReport(
                "trusted release expectation is invalid"
            )
        }
        executionProvenance = trustedExecutionProvenance
        corpus = trustedCorpus
        provider = trustedProvider
        environment = trustedEnvironment
        self.trustedAttempts = trustedAttempts
        self.attemptCount = attemptCount
        self.attemptIdentitySHA256 = attemptIdentitySHA256
    }
}
