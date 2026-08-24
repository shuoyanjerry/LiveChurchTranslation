import Foundation

public struct TranslationVerifiedFreeze: Sendable {
    public let statement: TranslationQualificationFreezeStatement
    public let authorityKeyID: String
    public let attestationFileSHA256: String

    public func releaseExpectation(
        report: TranslationQualificationReport,
        corpus: TranslationQualificationCorpus,
        files: TranslationFrozenEvidenceFiles,
        trustedHumanReviewers: [TranslationHumanReviewerIdentity],
        reviewerRegistrySHA256: String
    ) throws -> TranslationAttestedReleaseExpectation {
        try validateFrozenReport(
            report,
            corpus: corpus,
            files: files
        )
        let expectation = try TranslationReleaseExpectation(
            trustedExecutionProvenance: statement.executionProvenance,
            corpus: corpus,
            provider: statement.provider,
            environment: statement.environment,
            attempts: report.attempts,
            trustedHumanReviewers: trustedHumanReviewers,
            trustedHumanReviewPacketSHA256: files.reviewPacketSHA256,
            trustedHumanReviewerRegistrySHA256: reviewerRegistrySHA256
        )
        return TranslationAttestedReleaseExpectation(
            releaseExpectation: expectation,
            freezeAttestationSHA256: attestationFileSHA256,
            freezeAuthorityKeyID: authorityKeyID
        )
    }

    public func validateReviewPacket(
        _ data: Data,
        report: TranslationQualificationReport,
        corpus: TranslationQualificationCorpus,
        files: TranslationFrozenEvidenceFiles
    ) throws {
        try validateFrozenReport(
            report,
            corpus: corpus,
            files: files
        )
        let expectation = try TranslationReleaseExpectation(
            trustedExecutionProvenance: statement.executionProvenance,
            corpus: corpus,
            provider: statement.provider,
            environment: statement.environment,
            attempts: report.attempts
        )
        let packet = try TranslationHumanReviewEvidence.makeReviewPacket(
            report: report,
            expectation: expectation,
            reportFileSHA256: files.reportFileSHA256,
            postflightFileSHA256: files.postflightFileSHA256
        )
        guard try TranslationHumanReviewEvidence.encodeReviewPacket(packet) == data,
            try TranslationHumanReviewEvidence.decodeReviewPacket(from: data) == packet
        else { throw TranslationQualificationFreezeEvidence.invalid }
    }

    private func validateFrozenReport(
        _ report: TranslationQualificationReport,
        corpus: TranslationQualificationCorpus,
        files: TranslationFrozenEvidenceFiles
    ) throws {
        let binding = try TranslationHumanReviewEvidence.reportBinding(for: report)
        let attemptHash = try TranslationQualificationFreezeEvidence.attemptContentsSHA256(
            report.attempts
        )
        guard statement.reportFilename == files.reportFilename,
            statement.reportFileSHA256 == files.reportFileSHA256,
            statement.postflightFilename == files.postflightFilename,
            statement.postflightFileSHA256 == files.postflightFileSHA256,
            statement.reviewPacketFilename == files.reviewPacketFilename,
            statement.reviewPacketSHA256 == files.reviewPacketSHA256,
            statement.reportBinding == binding,
            statement.attemptContentsSHA256 == attemptHash,
            statement.executionProvenance == report.executionProvenance,
            statement.provider == report.provider,
            statement.environment == report.environment,
            statement.executionProvenance.manifestSHA256 == corpus.manifestSHA256,
            statement.executionProvenance.corpusSchemaSHA256 == corpus.schemaSHA256
        else { throw TranslationQualificationFreezeEvidence.invalid }
    }
}

public struct TranslationFrozenEvidenceFiles: Equatable, Sendable {
    public let reportFilename: String
    public let reportFileSHA256: String
    public let postflightFilename: String
    public let postflightFileSHA256: String
    public let reviewPacketFilename: String
    public let reviewPacketSHA256: String

    public init(
        reportFilename: String,
        reportFileSHA256: String,
        postflightFilename: String,
        postflightFileSHA256: String,
        reviewPacketFilename: String,
        reviewPacketSHA256: String
    ) {
        self.reportFilename = reportFilename
        self.reportFileSHA256 = reportFileSHA256
        self.postflightFilename = postflightFilename
        self.postflightFileSHA256 = postflightFileSHA256
        self.reviewPacketFilename = reviewPacketFilename
        self.reviewPacketSHA256 = reviewPacketSHA256
    }
}

public struct TranslationAttestedReleaseExpectation: Sendable {
    public let freezeAttestationSHA256: String
    public let freezeAuthorityKeyID: String
    let releaseExpectation: TranslationReleaseExpectation

    init(
        releaseExpectation: TranslationReleaseExpectation,
        freezeAttestationSHA256: String,
        freezeAuthorityKeyID: String
    ) {
        self.releaseExpectation = releaseExpectation
        self.freezeAttestationSHA256 = freezeAttestationSHA256
        self.freezeAuthorityKeyID = freezeAuthorityKeyID
    }
}
