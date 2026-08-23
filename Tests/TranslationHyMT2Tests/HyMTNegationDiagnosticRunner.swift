import Foundation
import TranslationAPI
import TranslationQualificationSupport
@testable import TranslationHyMT2

struct HyMTNegationDiagnosticRunner {
    let provider: HyMT2TranslationProvider
    let transport: HyMTNegationRecordingTransport
    let recorder: HyMTQualificationAttemptRecorder
    let providerConfiguration: HyMT2Configuration

    func run(
        corpus: TranslationQualificationCorpus,
        classified: HyMTNegationClassifiedEvidence
    ) async throws -> HyMTNegationDiagnosticRunResult {
        try await run(
            segments: corpus.manifest.segments,
            manifestSHA256: corpus.manifestSHA256,
            classified: classified
        )
    }

    func run(
        segments: [TranslationQualificationSegment],
        manifestSHA256: String,
        classified: HyMTNegationClassifiedEvidence
    ) async throws -> HyMTNegationDiagnosticRunResult {
        guard classified.attempts.count == segments.count else {
            throw TranslationQualificationError.invalidReport(
                "classified attempt count does not match corpus"
            )
        }
        var context = HyMTQualificationContext()
        var entries: [HyMTNegationDiagnosticEntry] = []
        var protectedModelOutputs: [String] = []
        for (segment, attempt) in zip(segments, classified.attempts) {
            try Task.checkCancellation()
            let recent = context.latest(for: segment.sourceID)
            try validateReplay(segment: segment, attempt: attempt, recent: recent)
            if HyMTNegationClassifiedReportLoader.isNegationFailure(attempt) {
                let result = try await diagnose(
                    segment: segment,
                    attempt: attempt,
                    recent: recent
                )
                entries.append(result.entry)
                protectedModelOutputs.append(contentsOf: result.protectedModelOutputs)
            }
            appendClassifiedSuccess(attempt, segment: segment, context: &context)
        }
        guard entries.count == classified.selectedSegmentIDs.count else {
            throw TranslationQualificationError.invalidReport(
                "negation failure replay coverage is incomplete"
            )
        }
        return makeResult(
            entries: entries,
            protectedModelOutputs: protectedModelOutputs,
            manifestSHA256: manifestSHA256,
            classifiedReportSHA256: classified.reportSHA256
        )
    }
}
