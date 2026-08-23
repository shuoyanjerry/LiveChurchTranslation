import ASRAPI
import DiagnosticsAPI
import Foundation
import SessionManagementAPI
import TranscriptAPI
import TranslationAPI
import VADAPI

extension UtteranceProcessor {
    func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit,
        sourceSegmentSequence: UInt64
    ) async throws -> TranscriptEntry {
        do {
            return try await dependencies.transcript.makeEntry(
                recognition: recognition,
                translation: translation,
                sourceAudit: sourceAudit,
                sourceSegmentSequence: sourceSegmentSequence
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw failure(stage: .persistence, error: error)
        }
    }

    func recordRecognitionAfterCriticalPath(
        _ normalized: RecognizedUtterance,
        original: RecognizedUtterance,
        segment: SpeechSegment
    ) {
        let diagnostics = dependencies.diagnostics
        Task {
            await diagnostics.record(
                DiagnosticEvent(
                    severity: .info,
                    component: "ASR",
                    message: "Recognized utterance",
                    measurements: [
                        "audio_seconds": segment.duration.seconds,
                        "normalization_applied": normalized.text == original.text ? 0.0 : 1.0,
                    ]
                )
            )
        }
    }

    func recordTranslationAfterCriticalPath(
        duration: Duration,
        review: TranslationReview?
    ) {
        let diagnostics = dependencies.diagnostics
        var measurements = ["latency_ms": duration.milliseconds]
        if let review {
            measurements["backend_review_required"] = 1
            measurements["review_issue_count"] = Double(review.issueCodes.count)
        }
        let recordedMeasurements = measurements
        Task {
            await diagnostics.record(
                DiagnosticEvent(
                    severity: .info,
                    component: "Translation",
                    message: "Translated utterance",
                    measurements: recordedMeasurements
                )
            )
        }
    }

    func failure(
        stage: LiveSessionIssueStage,
        error: any Error,
        pendingEntry: TranscriptEntry? = nil
    ) -> UtteranceProcessingFailure {
        UtteranceProcessingFailure(
            stage: stage,
            code: failureCode(stage: stage, error: error),
            message: error.localizedDescription,
            pendingEntry: pendingEntry,
            impact: failureImpact(stage: stage, error: error)
        )
    }

    private func failureImpact(
        stage: LiveSessionIssueStage,
        error: any Error
    ) -> UtteranceProcessingFailure.Impact {
        switch stage {
        case .recognition:
            guard let classified = error as? any ASRFailureImpactProviding else {
                return .pipeline
            }
            switch classified.asrFailureImpact {
            case .terminalUtterance: return .terminalUtterance
            case .ignoredUtterance, .runtime: return .pipeline
            }
        case .translation:
            guard let classified = error as? any TranslationFailureImpactProviding else {
                return .pipeline
            }
            switch classified.translationFailureImpact {
            case .terminalUtterance: return .terminalUtterance
            case .retryableUtterance: return .retryableUtterance
            case .runtime: return .pipeline
            }
        case .preparation, .audioProcessing, .persistence, .finalization:
            return .pipeline
        }
    }

    private func failureCode(
        stage: LiveSessionIssueStage,
        error: any Error
    ) -> String {
        switch stage {
        case .recognition:
            return (error as? any ASRFailureImpactProviding)?.asrFailureCode
                ?? "asr.unknown_failure"
        case .translation:
            return (error as? any TranslationFailureImpactProviding)?.translationFailureCode
                ?? "translation.unknown_failure"
        case .preparation: return "preparation.failure"
        case .audioProcessing: return "audio_processing.failure"
        case .persistence: return "persistence.failure"
        case .finalization: return "finalization.failure"
        }
    }
}

extension Duration {
    fileprivate var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    fileprivate var milliseconds: Double { seconds * 1_000 }
}
