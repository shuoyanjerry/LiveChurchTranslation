import AudioImportAPI
@testable import AudioImportSessionAdapter
import SessionManagementAPI
import Testing

@Suite struct AudioImportCompletionValidatorTests {
    @Test func fullySavedTranscriptIsAccepted() throws {
        try AudioImportCompletionValidator.validate(snapshot(outcome: .saved))
    }

    @Test func unresolvedTranscriptIsRejected() {
        #expect(throws: AudioImportError.self) {
            try AudioImportCompletionValidator.validate(
                snapshot(outcome: .savedWithUnresolvedUtterances(count: 3))
            )
        }
    }

    @Test func failedPhaseIsRejectedEvenWhenPersistenceSaved() {
        #expect(throws: AudioImportError.self) {
            try AudioImportCompletionValidator.validate(
                snapshot(phase: .failed(message: "Import incomplete"), outcome: .saved)
            )
        }
    }

    @Test func cancellationIsNotReportedAsAProcessingFailure() {
        #expect(throws: AudioImportError.cancelled) {
            try AudioImportCompletionValidator.validate(
                snapshot(outcome: .cancelledBeforeCapture)
            )
        }
    }

    @Test func persistenceFailureIsRejected() {
        #expect(throws: AudioImportError.self) {
            try AudioImportCompletionValidator.validate(
                snapshot(
                    outcome: .saveFailed(
                        message: "Could not save transcript",
                        unresolvedUtteranceCount: 0
                    )
                )
            )
        }
    }

    private func snapshot(
        phase: LiveSessionPhase = .idle,
        outcome: LiveSessionFinalizationOutcome
    ) -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: nil,
            phase: phase,
            transcript: [],
            captureStartedAt: nil,
            modelStatus: nil,
            statusMessage: "Finished",
            finalizationOutcome: outcome
        )
    }
}
