public enum TranslationQualificationCompletionPolicy {
    public static func validate(
        _ attempt: TranslationQualificationAttempt
    ) throws {
        let outcomes = attempt.completionOutcomes
        guard attempt.completionAttemptCount == outcomes.count else {
            throw invalid("completion outcome count mismatch")
        }
        guard attempt.strictRetryUsed == containsPhase("strictRetry", outcomes: outcomes) else {
            throw invalid("strict retry accounting mismatch")
        }
        guard
            (attempt.safetyFallbackUsed ?? false)
                == containsPhase("safetyFallback", outcomes: outcomes)
        else { throw invalid("safety fallback accounting mismatch") }
        let allowed = attempt.status == .success ? successful : failed
        guard allowed.contains(outcomes) else {
            throw invalid("completion state transition is invalid")
        }
        if attempt.status == .success {
            let reviewCodes = attempt.backendReviewIssueCodes ?? []
            let reviewed = !reviewCodes.isEmpty
            guard reviewed == reviewedSuccesses.contains(outcomes) else {
                throw invalid("backend review disposition does not match completion transition")
            }
            let usedSafetyFallback = outcomes.last == "safetyFallback.accepted"
            if usedSafetyFallback && !reviewCodes.contains("quality.pronoun_alignment") {
                throw invalid("safety fallback lacks its mandatory pronoun review")
            }
        }
    }

    public static func approvesContext(
        _ attempt: TranslationQualificationAttempt
    ) -> Bool {
        guard attempt.status == .success,
            (attempt.backendReviewIssueCodes ?? []).isEmpty
        else { return false }
        return (try? validate(attempt)) != nil
    }

    private static let approvedSuccesses: Set<[String]> = [
        ["initial.accepted"],
        ["initial.validationRejected", "strictRetry.accepted"],
    ]

    private static let reviewedSuccesses: Set<[String]> = [
        ["initial.validationRejected", "strictRetry.validationRejected"],
        ["initial.validationRejected", "strictRetry.transportFailed"],
        [
            "initial.validationRejected",
            "strictRetry.validationRejected",
            "safetyFallback.accepted",
        ],
    ]

    private static let successful = approvedSuccesses.union(reviewedSuccesses)

    private static let failed: Set<[String]> = [
        [],
        ["initial.transportFailed"],
        ["initial.validationRejected", "strictRetry.validationRejected"],
        ["initial.validationRejected", "strictRetry.transportFailed"],
        [
            "initial.validationRejected",
            "strictRetry.validationRejected",
            "safetyFallback.validationRejected",
        ],
        [
            "initial.validationRejected",
            "strictRetry.validationRejected",
            "safetyFallback.transportFailed",
        ],
    ]

    private static func containsPhase(_ phase: String, outcomes: [String]) -> Bool {
        outcomes.contains { $0.hasPrefix("\(phase).") }
    }

    private static func invalid(_ message: String) -> TranslationQualificationError {
        .invalidReport(message)
    }
}
