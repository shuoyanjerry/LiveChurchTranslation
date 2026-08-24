import AudioImportAPI
@testable import AudioImportSessionAdapter
import Foundation
import SessionManagementAPI
import Testing

@Suite struct AudioImportCompletionValidatorTests {
    @Test func fullySavedTranscriptIsAccepted() throws {
        try AudioImportCompletionValidator.validate(snapshot(outcome: .saved))
    }

    @Test func unresolvedTranscriptIsRejected() {
        let sessionID = UUID()
        #expect(
            throws: AudioImportError.savedWithIncompleteTranscript(sessionID: sessionID)
        ) {
            try AudioImportCompletionValidator.validate(
                snapshot(outcome: .savedWithUnresolvedUtterances(count: 3)),
                savedSessionID: sessionID
            )
        }
    }

    @Test func failedPhaseIsRejectedEvenWhenPersistenceSaved() {
        let sessionID = UUID()
        #expect(
            throws: AudioImportError.savedWithIncompleteTranscript(sessionID: sessionID)
        ) {
            try AudioImportCompletionValidator.validate(
                snapshot(phase: .failed(message: "Import incomplete"), outcome: .saved),
                savedSessionID: sessionID
            )
        }
    }

    @Test func incompleteTranscriptUsesConcisePublicMessageWithoutIdentity() {
        let sessionID = UUID()
        let error = AudioImportError.savedWithIncompleteTranscript(sessionID: sessionID)

        #expect(error.errorDescription == "录音已保存，听抄未完整。")
        #expect(!(error.errorDescription ?? "").contains(sessionID.uuidString))
        #expect(!String(describing: error).contains(sessionID.uuidString))
        #expect(!String(reflecting: error).contains(sessionID.uuidString))
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
