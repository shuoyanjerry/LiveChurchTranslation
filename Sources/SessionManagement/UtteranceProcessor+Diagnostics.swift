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

    func recordTranslationAfterCriticalPath(duration: Duration) {
        let diagnostics = dependencies.diagnostics
        Task {
            await diagnostics.record(
                DiagnosticEvent(
                    severity: .info,
                    component: "Translation",
                    message: "Translated utterance",
                    measurements: ["latency_ms": duration.milliseconds]
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
            message: error.localizedDescription,
            pendingEntry: pendingEntry
        )
    }
}

extension Duration {
    fileprivate var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    fileprivate var milliseconds: Double { seconds * 1_000 }
}
