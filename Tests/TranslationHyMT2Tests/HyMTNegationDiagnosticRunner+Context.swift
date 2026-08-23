import Foundation
import TranslationQualificationSupport

extension HyMTNegationDiagnosticRunner {
    func makeResult(
        entries: [HyMTNegationDiagnosticEntry],
        protectedModelOutputs: [String],
        manifestSHA256: String,
        classifiedReportSHA256: String
    ) -> HyMTNegationDiagnosticRunResult {
        HyMTNegationDiagnosticRunResult(
            report: HyMTNegationDiagnosticReport(
                schemaVersion: 1,
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                manifestSHA256: manifestSHA256,
                classifiedReportSHA256: classifiedReportSHA256,
                modelSHA256: HyMTQualificationConfiguration.modelSHA256,
                entries: entries
            ),
            protectedModelOutputs: protectedModelOutputs
        )
    }

    func validateReplay(
        segment: TranslationQualificationSegment,
        attempt: TranslationQualificationAttempt,
        recent: [HyMTQualificationPersistedTurn]
    ) throws {
        guard
            attempt.segmentID == segment.id,
            attempt.sourceID == segment.sourceID,
            attempt.sequence == segment.sequence,
            attempt.contextSegmentIDs == recent.segmentIDs
        else {
            throw TranslationQualificationError.invalidReport(
                "classified report order or replay context is inconsistent"
            )
        }
    }

    func appendClassifiedSuccess(
        _ attempt: TranslationQualificationAttempt,
        segment: TranslationQualificationSegment,
        context: inout HyMTQualificationContext
    ) {
        guard
            TranslationQualificationCompletionPolicy.approvesContext(attempt),
            let target = attempt.hypothesisEnglish
        else { return }
        context.append(
            HyMTQualificationPersistedTurn(
                segmentID: segment.id,
                sequence: segment.sequence,
                sourceText: attempt.translationSourceText,
                targetText: target
            ),
            sourceID: segment.sourceID
        )
    }
}
