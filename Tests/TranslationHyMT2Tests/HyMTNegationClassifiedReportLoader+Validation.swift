import Foundation
@testable import TranslationQualificationSupport

extension HyMTNegationClassifiedReportLoader {
    static func validate(
        _ report: TranslationQualificationReport,
        corpus: TranslationQualificationCorpus
    ) throws {
        try validateProvenance(report, corpus: corpus)
        try validateAttempts(report.attempts, segments: corpus.manifest.segments)
        guard report.aggregate == TranslationQualificationReportBuilder.aggregate(report.attempts)
        else {
            throw invalid("classified report aggregate is inconsistent")
        }
    }

    private static func validateProvenance(
        _ report: TranslationQualificationReport,
        corpus: TranslationQualificationCorpus
    ) throws {
        guard
            report.schemaVersion == 1,
            report.manifestSHA256 == corpus.manifestSHA256,
            report.schemaSHA256 == corpus.schemaSHA256,
            report.corpusID == corpus.manifest.corpusID,
            report.provider.modelSHA256 == HyMTQualificationConfiguration.modelSHA256,
            report.provider.runtimeSHA256 == HyMTQualificationConfiguration.helperSHA256
        else { throw invalid("classified report provenance does not match inputs") }
    }

    private static func validateAttempts(
        _ attempts: [TranslationQualificationAttempt],
        segments: [TranslationQualificationSegment]
    ) throws {
        guard attempts.count == segments.count else {
            throw invalid("classified report attempt count is inconsistent")
        }
        var persistedBySource: [String: [String]] = [:]
        for (attempt, segment) in zip(attempts, segments) {
            try validateAttempt(attempt, segment: segment)
            let expected = Array(persistedBySource[segment.sourceID, default: []].suffix(2))
            guard attempt.contextSegmentIDs == expected else {
                throw invalid("classified report context sequence is inconsistent")
            }
            if TranslationQualificationCompletionPolicy.approvesContext(attempt) {
                persistedBySource[segment.sourceID, default: []].append(segment.id)
            }
        }
    }

    private static func validateAttempt(
        _ attempt: TranslationQualificationAttempt,
        segment: TranslationQualificationSegment
    ) throws {
        guard
            attempt.segmentID == segment.id,
            attempt.sourceID == segment.sourceID,
            attempt.sequence == segment.sequence,
            attempt.originalChinese == segment.originalChinese,
            attempt.observedASRText == segment.observedASRAmbiguousChinese,
            attempt.humanReferenceEnglish == segment.referenceEnglish,
            attempt.referenceProfileID == segment.referenceProfileID,
            attempt.semanticReviewEligible == segment.qualification.semanticScoringEligible,
            !attempt.exactStringMetricEligible,
            !attempt.translationSourceText.isEmpty,
            attempt.latencySeconds.isFinite,
            attempt.latencySeconds >= 0
        else { throw invalid("classified attempt is not bound to its corpus segment") }
        try validateOutcome(attempt)
        try validatePronouns(attempt, segment: segment)
        try TranslationSourceMutationValidator.validate(attempt: attempt, segment: segment)
    }

    private static func invalid(_ message: String) -> TranslationQualificationError {
        .invalidReport(message)
    }
}
