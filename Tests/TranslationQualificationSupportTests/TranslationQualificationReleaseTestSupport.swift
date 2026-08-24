import Foundation
import Testing
import TranslationQualificationSupport

struct TranslationReleaseValues {
    let workspace: SyntheticTranslationWorkspace
    let report: TranslationQualificationReport
    let expectation: TranslationReleaseExpectation
}

func releaseValues(
    requiresHumanReview: Bool = true
) throws -> TranslationReleaseValues {
    let workspace = try SyntheticTranslationWorkspace(
        requiresHumanReview: requiresHumanReview
    )
    let corpus = try workspace.load()
    let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
    return TranslationReleaseValues(
        workspace: workspace,
        report: report,
        expectation: try SyntheticHumanReviewSettlementFactory.expectation(
            report: report,
            corpus: corpus
        )
    )
}

func wrongExpectations(
    _ correct: TranslationReleaseExpectation
) throws -> [TranslationReleaseExpectation] {
    let provenance = correct.executionProvenance
    let trustedAttempts = try SyntheticTranslationReportFactory.build(
        corpus: correct.corpus
    ).attempts
    let wrongSource = TranslationQualificationBundleDigest(
        format: provenance.sourceBundle.format,
        entryCount: provenance.sourceBundle.entryCount,
        byteCount: provenance.sourceBundle.byteCount,
        sha256: String(repeating: "f", count: 64)
    )
    return try makeWrongExpectations(
        correct,
        provenance: provenance,
        wrongSource: wrongSource,
        trustedAttempts: trustedAttempts
    )
}

private func makeWrongExpectations(
    _ correct: TranslationReleaseExpectation,
    provenance: TranslationExecutionProvenance,
    wrongSource: TranslationQualificationBundleDigest,
    trustedAttempts: [TranslationQualificationAttempt]
) throws -> [TranslationReleaseExpectation] {
    [
        try releaseExpectation(
            correct,
            provenance: copy(provenance, sourceBundle: wrongSource),
            attempts: trustedAttempts
        ),
        try releaseExpectation(
            correct,
            provenance: provenance,
            attempts: trustedAttempts,
            attemptCount: correct.attemptCount + 1
        ),
        try releaseExpectation(
            correct,
            provenance: provenance,
            attempts: trustedAttempts,
            identity: String(repeating: "0", count: 64)
        ),
    ]
}

private func releaseExpectation(
    _ correct: TranslationReleaseExpectation,
    provenance: TranslationExecutionProvenance,
    attempts: [TranslationQualificationAttempt],
    attemptCount: Int? = nil,
    identity: String? = nil
) throws -> TranslationReleaseExpectation {
    try TranslationReleaseExpectation(
        trustedExecutionProvenance: provenance,
        trustedCorpus: correct.corpus,
        trustedProvider: correct.provider,
        trustedEnvironment: correct.environment,
        trustedAttempts: attempts,
        attemptCount: attemptCount ?? correct.attemptCount,
        attemptIdentitySHA256: identity ?? correct.attemptIdentitySHA256,
        trustedHumanReviewers: correct.trustedHumanReviewers,
        trustedHumanReviewPacketSHA256: correct.trustedHumanReviewPacketSHA256,
        trustedHumanReviewerRegistrySHA256: correct.trustedHumanReviewerRegistrySHA256
    )
}

private func copy(
    _ value: TranslationExecutionProvenance,
    sourceBundle: TranslationQualificationBundleDigest
) -> TranslationExecutionProvenance {
    TranslationExecutionProvenance(
        version: value.version,
        buildConfiguration: value.buildConfiguration,
        sourceBundle: sourceBundle,
        testExecutable: value.testExecutable,
        model: value.model,
        helper: value.helper,
        runtimeBundle: value.runtimeBundle,
        configurationSHA256: value.configurationSHA256,
        manifestSHA256: value.manifestSHA256,
        corpusSchemaSHA256: value.corpusSchemaSHA256
    )
}

func report(
    _ value: TranslationQualificationReport,
    mutate: (inout [String: Any]) throws -> Void
) throws -> TranslationQualificationReport {
    var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
    )
    try mutate(&object)
    return try JSONDecoder().decode(
        TranslationQualificationReport.self,
        from: JSONSerialization.data(withJSONObject: object)
    )
}

func emptyReleaseAggregate() -> [String: Any] {
    [
        "attemptCount": 0, "successCount": 0, "failureCount": 0,
        "strictRetryCount": 0, "checkPassCount": 0, "checkFailCount": 0,
        "humanReviewRequiredCount": 0,
        "latency": [
            "minimumSeconds": 0, "medianSeconds": 0,
            "p95Seconds": 0, "maximumSeconds": 0,
        ],
    ]
}
