public enum TranslationQualificationCompletionPolicy {
    public static func validate(
        _ attempt: TranslationQualificationAttempt
    ) throws {
        let outcomes = attempt.completionOutcomes
        guard attempt.completionAttemptCount == outcomes.count else {
            throw invalid("completion outcome count mismatch")
        }
        guard attempt.strictRetryUsed == (outcomes.count == 2) else {
            throw invalid("strict retry accounting mismatch")
        }
        let allowed = attempt.status == .success ? successful : failed
        guard allowed.contains(outcomes) else {
            throw invalid("completion state transition is invalid")
        }
    }

    public static func approvesContext(
        _ attempt: TranslationQualificationAttempt
    ) -> Bool {
        guard attempt.status == .success else { return false }
        return (try? validate(attempt)) != nil
    }

    private static let successful: Set<[String]> = [
        ["initial.accepted"],
        ["initial.validationRejected", "strictRetry.accepted"],
    ]

    private static let failed: Set<[String]> = [
        [],
        ["initial.transportFailed"],
        ["initial.validationRejected", "strictRetry.validationRejected"],
        ["initial.validationRejected", "strictRetry.transportFailed"],
    ]

    private static func invalid(_ message: String) -> TranslationQualificationError {
        .invalidReport(message)
    }
}
