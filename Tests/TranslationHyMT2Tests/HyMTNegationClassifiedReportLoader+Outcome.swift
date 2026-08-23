@testable import TranslationQualificationSupport

extension HyMTNegationClassifiedReportLoader {
    static func validateOutcome(_ attempt: TranslationQualificationAttempt) throws {
        if attempt.status == .success {
            guard
                !(attempt.hypothesisEnglish ?? "").isEmpty,
                attempt.failureCode == nil,
                (1...2).contains(attempt.completionAttemptCount)
            else { throw invalidOutcome }
        } else {
            guard
                attempt.hypothesisEnglish == nil,
                TranslationQualificationReportBuilder.isFailureCode(attempt.failureCode),
                (0...2).contains(attempt.completionAttemptCount)
            else { throw invalidOutcome }
        }
        try TranslationQualificationCompletionPolicy.validate(attempt)
    }

    static func validatePronouns(
        _ attempt: TranslationQualificationAttempt,
        segment: TranslationQualificationSegment
    ) throws {
        guard attempt.pronounResults.count == segment.pronounOccurrences.count else {
            throw invalidOutcome
        }
        for (result, occurrence) in zip(attempt.pronounResults, segment.pronounOccurrences) {
            guard
                result.occurrenceID == occurrence.id,
                result.expectedGuidance == occurrence.expectedGuidance,
                allowedGuidance.contains(result.actualGuidance)
            else { throw invalidOutcome }
        }
    }

    private static var invalidOutcome: TranslationQualificationError {
        .invalidReport("classified attempt outcome evidence is inconsistent")
    }

    private static let allowedGuidance = Set([
        "none", "unresolvedSpokenMandarin", "verifiedFemale", "verifiedMale", "verifiedDeity",
    ])
}
