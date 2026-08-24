import Foundation

public enum TranslationQualificationReportBuilder {
    public static func build(
        generatedAt: String,
        corpus: TranslationQualificationCorpus,
        provider: TranslationQualificationProvider,
        environment: TranslationQualificationEnvironment,
        executionProvenance: TranslationExecutionProvenance? = nil,
        attempts: [TranslationQualificationAttempt]
    ) throws -> TranslationQualificationReport {
        try validateMetadata(generatedAt, provider: provider, environment: environment)
        if let executionProvenance {
            try TranslationProvenanceValidator.validate(
                executionProvenance,
                corpus: corpus,
                provider: provider
            )
        }
        try validateAttempts(attempts, manifest: corpus.manifest)
        return TranslationQualificationReport(
            schemaVersion: executionProvenance == nil ? 1 : 2,
            generatedAt: generatedAt,
            corpusID: corpus.manifest.corpusID,
            manifestSHA256: corpus.manifestSHA256,
            schemaSHA256: corpus.schemaSHA256,
            provider: provider,
            environment: environment,
            executionProvenance: executionProvenance,
            metricPolicy: metricPolicy,
            attempts: attempts,
            aggregate: aggregate(attempts)
        )
    }

    private static func validateMetadata(
        _ generatedAt: String,
        provider: TranslationQualificationProvider,
        environment: TranslationQualificationEnvironment
    ) throws {
        try require(isISO8601(generatedAt), "invalid generatedAt")
        try require(!provider.identifier.isEmpty, "provider identifier is empty")
        try require(!provider.modelRevision.isEmpty, "model revision is empty")
        try require(isSHA(provider.modelSHA256), "model hash is invalid")
        try require(!provider.runtimeRevision.isEmpty, "runtime revision is empty")
        try require(isSHA(provider.runtimeSHA256), "runtime hash is invalid")
        try require(!provider.settings.isEmpty, "provider settings are empty")
        try require(provider.settings.allSatisfy { !$0.key.isEmpty && !$0.value.isEmpty }, "empty setting")
        let values = [
            environment.hardware, environment.operatingSystem,
            environment.repositoryRevision, environment.backgroundLoad,
        ]
        try require(values.allSatisfy { !$0.isEmpty }, "environment metadata is empty")
    }

    private static func validateAttempts(
        _ attempts: [TranslationQualificationAttempt],
        manifest: TranslationQualificationManifest
    ) throws {
        try require(attempts.count == manifest.segments.count, "attempt count mismatch")
        var persistedBySource: [String: [String]] = [:]
        for (attempt, segment) in zip(attempts, manifest.segments) {
            try validate(attempt, segment: segment)
            let expectedContext = Array(persistedBySource[segment.sourceID, default: []].suffix(2))
            try require(attempt.contextSegmentIDs == expectedContext, "context is not last two successes")
            if TranslationQualificationCompletionPolicy.approvesContext(attempt) {
                persistedBySource[segment.sourceID, default: []].append(segment.id)
            }
        }
    }

    private static func validate(
        _ attempt: TranslationQualificationAttempt,
        segment: TranslationQualificationSegment
    ) throws {
        try require(attempt.segmentID == segment.id, "segment order or ID mismatch")
        try require(attempt.sourceID == segment.sourceID, "source ID mismatch")
        try require(attempt.sequence == segment.sequence, "sequence mismatch")
        try require(attempt.originalChinese == segment.originalChinese, "original source mutated")
        try require(
            attempt.observedASRText == segment.observedASRAmbiguousChinese,
            "observed ASR text mismatch"
        )
        try require(!attempt.translationSourceText.isEmpty, "translation source is empty")
        try require(attempt.humanReferenceEnglish == segment.referenceEnglish, "reference mismatch")
        try require(
            attempt.semanticReviewEligible == segment.qualification.semanticScoringEligible,
            "semantic review eligibility mismatch"
        )
        try require(!attempt.exactStringMetricEligible, "exact string metric is forbidden")
        try require(attempt.latencySeconds.isFinite && attempt.latencySeconds >= 0, "invalid latency")
        try require(attempt.contextSegmentIDs.count <= 2, "context exceeds two entries")
        try validateOutcome(attempt)
        let traceIntegrity = try TranslationComputedEvidenceValidator.validate(
            attempt: attempt,
            segment: segment
        )
        try validatePronouns(attempt, segment: segment, traceIntegrity: traceIntegrity)
        try TranslationSourceMutationValidator.validate(attempt: attempt, segment: segment)
    }
}

extension TranslationQualificationReportBuilder {
    private static func validatePronouns(
        _ attempt: TranslationQualificationAttempt,
        segment: TranslationQualificationSegment,
        traceIntegrity: TranslationQualificationCheckStatus
    ) throws {
        let expectedOccurrences = segment.pronounOccurrences.map(\.id)
        try require(
            attempt.pronounResults.map(\.occurrenceID) == expectedOccurrences,
            "pronoun occurrence mismatch"
        )
        try require(
            zip(attempt.pronounResults, segment.pronounOccurrences).allSatisfy {
                $0.0.expectedGuidance == $0.1.expectedGuidance
            },
            "expected pronoun policy mismatch"
        )
        try TranslationPronounResultValidator.validate(
            attempt.pronounResults,
            occurrences: segment.pronounOccurrences,
            hypothesisAvailable: attempt.hypothesisEnglish != nil,
            traceIntegrity: traceIntegrity
        )
    }

    private static func validateOutcome(_ attempt: TranslationQualificationAttempt) throws {
        if attempt.status == .success {
            try require(!(attempt.hypothesisEnglish ?? "").isEmpty, "success lacks hypothesis")
            try require(attempt.failureCode == nil, "success has failure code")
            try require((1...3).contains(attempt.completionAttemptCount), "invalid success attempts")
        } else {
            try require(attempt.hypothesisEnglish == nil, "failure has hypothesis")
            try require(isFailureCode(attempt.failureCode), "failure code is absent or unsafe")
            try require(
                (attempt.backendReviewIssueCodes ?? []).isEmpty,
                "provider failure has backend review codes"
            )
            try require((0...3).contains(attempt.completionAttemptCount), "invalid failure attempts")
        }
        try validateBackendReview(attempt.backendReviewIssueCodes ?? [])
        try TranslationQualificationCompletionPolicy.validate(attempt)
    }

    private static func validateBackendReview(_ issueCodes: [String]) throws {
        try require(issueCodes == Array(Set(issueCodes)).sorted(), "backend review codes drifted")
        try require(
            issueCodes.allSatisfy {
                $0.hasPrefix("quality.") && isFailureCode($0)
            },
            "backend review code is absent or unsafe"
        )
    }
}
