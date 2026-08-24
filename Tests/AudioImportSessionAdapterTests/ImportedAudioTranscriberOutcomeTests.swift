import AudioCaptureAPI
import AudioImportAPI
import AudioImportSessionAdapter
import Foundation
import SessionManagementAPI
import SettingsAPI
import Testing

@Suite @MainActor struct ImportedAudioTranscriberOutcomeTests {
    @Test func savedOutcomeCompletes() async throws {
        let sessionID = UUID()
        let transcriber = makeTranscriber(
            terminalSnapshot(outcome: .saved),
            sessionID: sessionID
        )

        try await transcriber.importAudio(
            from: URL(fileURLWithPath: "/tmp/saved.wav"),
            mode: .mandarinToEnglish
        )
    }

    @Test func partialSaveCarriesObservedSessionIdentity() async {
        let sessionID = UUID()
        let transcriber = makeTranscriber(
            terminalSnapshot(
                phase: .failed(message: "incomplete"),
                outcome: .savedWithUnresolvedUtterances(count: 2)
            ),
            sessionID: sessionID
        )

        await #expect(
            throws: AudioImportError.savedWithIncompleteTranscript(sessionID: sessionID)
        ) {
            try await transcriber.importAudio(
                from: URL(fileURLWithPath: "/tmp/partial.wav"),
                mode: .englishToSimplifiedChinese
            )
        }
    }

    @Test func unsavedFailureDoesNotClaimRecordingWasSaved() async {
        let sessionID = UUID()
        let transcriber = makeTranscriber(
            terminalSnapshot(
                phase: .failed(message: "save failed"),
                outcome: .saveFailed(message: "save failed", unresolvedUtteranceCount: 0)
            ),
            sessionID: sessionID
        )

        await #expect(throws: AudioImportError.transcriptionFailed("save failed")) {
            try await transcriber.importAudio(
                from: URL(fileURLWithPath: "/tmp/failed.wav"),
                mode: .mandarinToEnglish
            )
        }
    }

    private func makeTranscriber(
        _ terminal: LiveSessionSnapshot,
        sessionID: UUID
    ) -> ImportedAudioTranscriber {
        let active = LiveSessionSnapshot(
            sessionID: sessionID,
            phase: .recognizing,
            transcript: [],
            modelStatus: nil,
            statusMessage: ""
        )
        let controller = TerminalImportController(events: [active, terminal])
        return ImportedAudioTranscriber(
            inputDeviceID: AudioInputID(rawValue: "outcome-test")
        ) { _, _, _ in controller }
    }

    private func terminalSnapshot(
        phase: LiveSessionPhase = .idle,
        outcome: LiveSessionFinalizationOutcome
    ) -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: nil,
            phase: phase,
            transcript: [],
            modelStatus: nil,
            statusMessage: "finished",
            finalizationOutcome: outcome
        )
    }
}

private actor TerminalImportController: LiveSessionController {
    private let snapshots: [LiveSessionSnapshot]

    init(events: [LiveSessionSnapshot]) {
        snapshots = events
    }

    func events() -> AsyncStream<LiveSessionEvent> {
        AsyncStream { continuation in
            snapshots.forEach { continuation.yield(.stateChanged($0)) }
            continuation.finish()
        }
    }

    func start(inputDeviceID _: AudioInputID?) {}
    func stop() {}

    func currentSnapshot() -> LiveSessionSnapshot {
        snapshots.last
            ?? LiveSessionSnapshot(
                sessionID: nil,
                phase: .idle,
                transcript: [],
                modelStatus: nil,
                statusMessage: ""
            )
    }
}
