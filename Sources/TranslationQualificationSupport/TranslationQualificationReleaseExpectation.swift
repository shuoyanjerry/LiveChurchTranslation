public struct TranslationReleaseExpectation: Sendable {
    public let executionProvenance: TranslationExecutionProvenance
    public let corpus: TranslationQualificationCorpus
    public let provider: TranslationQualificationProvider
    public let environment: TranslationQualificationEnvironment
    public let attemptCount: Int
    public let attemptIdentitySHA256: String
    public let trustedHumanReviewers: [TranslationHumanReviewerIdentity]
    public let trustedHumanReviewPacketSHA256: String?
    public let trustedHumanReviewerRegistrySHA256: String?
    let trustedAttempts: [TranslationQualificationAttempt]

    public init(
        trustedExecutionProvenance: TranslationExecutionProvenance,
        corpus: TranslationQualificationCorpus,
        provider: TranslationQualificationProvider,
        environment: TranslationQualificationEnvironment,
        attempts: [TranslationQualificationAttempt],
        trustedHumanReviewers: [TranslationHumanReviewerIdentity] = [],
        trustedHumanReviewPacketSHA256: String? = nil,
        trustedHumanReviewerRegistrySHA256: String? = nil
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
            ),
            trustedHumanReviewers: trustedHumanReviewers,
            trustedHumanReviewPacketSHA256: trustedHumanReviewPacketSHA256,
            trustedHumanReviewerRegistrySHA256: trustedHumanReviewerRegistrySHA256
        )
    }

    public init(
        trustedExecutionProvenance: TranslationExecutionProvenance,
        trustedCorpus: TranslationQualificationCorpus,
        trustedProvider: TranslationQualificationProvider,
        trustedEnvironment: TranslationQualificationEnvironment,
        trustedAttempts: [TranslationQualificationAttempt],
        attemptCount: Int,
        attemptIdentitySHA256: String,
        trustedHumanReviewers: [TranslationHumanReviewerIdentity] = [],
        trustedHumanReviewPacketSHA256: String? = nil,
        trustedHumanReviewerRegistrySHA256: String? = nil
    ) throws {
        try Self.validateReportInputs(
            trustedExecutionProvenance,
            corpus: trustedCorpus,
            provider: trustedProvider,
            environment: trustedEnvironment,
            attempts: trustedAttempts
        )
        guard
            TranslationProvenanceValidator.isStructurallyValid(
                trustedExecutionProvenance
            ),
            attemptCount > 0,
            TranslationProvenanceValidator.isSHA(attemptIdentitySHA256),
            Self.validHumanReviewTrust(
                reviewers: trustedHumanReviewers,
                packetSHA256: trustedHumanReviewPacketSHA256,
                registrySHA256: trustedHumanReviewerRegistrySHA256
            )
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
        self.trustedHumanReviewers = trustedHumanReviewers
        self.trustedHumanReviewPacketSHA256 = trustedHumanReviewPacketSHA256
        self.trustedHumanReviewerRegistrySHA256 = trustedHumanReviewerRegistrySHA256
    }

    private static func validHumanReviewTrust(
        reviewers: [TranslationHumanReviewerIdentity],
        packetSHA256: String?,
        registrySHA256: String?
    ) -> Bool {
        if reviewers.isEmpty {
            return packetSHA256 == nil && registrySHA256 == nil
        }
        guard let packetSHA256, let registrySHA256 else { return false }
        return HumanReviewSignatureValidator.validTrustedReviewers(reviewers)
            && TranslationProvenanceValidator.isSHA(packetSHA256)
            && TranslationProvenanceValidator.isSHA(registrySHA256)
    }

    private static func validateReportInputs(
        _ provenance: TranslationExecutionProvenance,
        corpus: TranslationQualificationCorpus,
        provider: TranslationQualificationProvider,
        environment: TranslationQualificationEnvironment,
        attempts: [TranslationQualificationAttempt]
    ) throws {
        try TranslationProvenanceValidator.validate(
            provenance,
            corpus: corpus,
            provider: provider
        )
        _ = try TranslationQualificationReportBuilder.build(
            generatedAt: "2001-01-01T00:00:00Z",
            corpus: corpus,
            provider: provider,
            environment: environment,
            executionProvenance: provenance,
            attempts: attempts
        )
    }
}
