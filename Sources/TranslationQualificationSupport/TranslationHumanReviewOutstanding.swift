enum TranslationHumanReviewOutstanding {
    static func count(in report: TranslationQualificationReport) -> Int {
        report.attempts.reduce(0) { count, attempt in
            count + reviews(in: attempt) + (attempt.backendReviewIssueCodes ?? []).count
        }
    }

    private static func reviews(in attempt: TranslationQualificationAttempt) -> Int {
        attempt.preservationChecks.filter { $0.status == .humanReviewRequired }.count
            + attempt.glossaryTerms.filter { $0.status == .humanReviewRequired }.count
            + attempt.pronounResults.reduce(0) { count, result in
                count + (result.guidanceStatus == .humanReviewRequired ? 1 : 0)
                    + (result.englishPolicyStatus == .humanReviewRequired ? 1 : 0)
            }
    }
}
