import TranslationQualificationSupport

extension HyMTNegationDiagnosticTestFixture {
    static func classifiedAttempts(
        _ segments: [TranslationQualificationSegment]
    ) -> [TranslationQualificationAttempt] {
        [
            success(
                segments[0],
                hypothesis: "Prior approved context.",
                contextIDs: []
            ),
            failure(
                segments[1],
                contextIDs: [segments[0].id],
                failureCode: "hymt.strict.zh"
            ),
            failure(
                segments[2],
                contextIDs: [segments[0].id],
                failureCode: "hymt.strict.neg"
            ),
        ]
    }

    static func report(
        entries: [HyMTNegationDiagnosticEntry]
    ) -> HyMTNegationDiagnosticReport {
        HyMTNegationDiagnosticReport(
            schemaVersion: 1,
            generatedAt: "2026-08-22T12:00:00Z",
            manifestSHA256: String(repeating: "a", count: 64),
            classifiedReportSHA256: String(repeating: "b", count: 64),
            modelSHA256: String(repeating: "c", count: 64),
            entries: entries
        )
    }

    private static func success(
        _ segment: TranslationQualificationSegment,
        hypothesis: String,
        contextIDs: [String]
    ) -> TranslationQualificationAttempt {
        attempt(
            segment,
            status: .success,
            hypothesis: hypothesis,
            contextIDs: contextIDs,
            failureCode: nil
        )
    }

    private static func failure(
        _ segment: TranslationQualificationSegment,
        contextIDs: [String],
        failureCode: String
    ) -> TranslationQualificationAttempt {
        attempt(
            segment,
            status: .failure,
            hypothesis: nil,
            contextIDs: contextIDs,
            failureCode: failureCode
        )
    }

    private static func attempt(
        _ segment: TranslationQualificationSegment,
        status: TranslationQualificationAttemptStatus,
        hypothesis: String?,
        contextIDs: [String],
        failureCode: String?
    ) -> TranslationQualificationAttempt {
        let outcomes =
            status == .success
            ? ["initial.accepted"]
            : ["initial.validationRejected", "strictRetry.validationRejected"]
        return TranslationQualificationAttempt(
            segment: segment,
            status: status,
            hypothesisEnglish: hypothesis,
            translationSourceText: segment.observedASRAmbiguousChinese,
            contextSegmentIDs: contextIDs,
            strictRetryUsed: outcomes.count == 2,
            completionAttemptCount: outcomes.count,
            completionOutcomes: outcomes,
            latencySeconds: 0.01,
            failureCode: failureCode,
            glossaryTerms: [],
            preservationChecks: [],
            pronounResults: []
        )
    }
}
