import AudioCaptureAPI
import Foundation
import ModelRuntimeAPI
import SessionManagementAPI
import SettingsAPI
import TranscriptAPI

struct StartedSessionCapture: Sendable {
    let audioStream: AsyncThrowingStream<AudioFrame, any Error>
}

struct PreparedSessionInference: Sendable {
    let modelStatus: ModelRuntimeStatus
    let recoveryIssues: [LiveSessionIssue]
}

struct SessionPreparer: Sendable {
    let dependencies: LiveSessionDependencies
    let models: SessionModelDescriptors
    let modelPreparation: InferenceModelPreparationCoordinator
    let utteranceProcessor: UtteranceProcessor
    let sessionKind: TranscriptSessionKind
    let sessionTitle: String?

    func loadMode() async throws -> TranslationMode {
        try Task.checkCancellation()
        return try await dependencies.settings.load().translationMode
    }

    func prepareInference(
        mode: TranslationMode,
        excludingSessionID: UUID
    ) async throws -> PreparedSessionInference {
        try await loadModels()
        let recoveryIssues = await replayRecoverableUtterances(
            excludingSessionID: excludingSessionID
        )
        // Replay exercises both inference runtimes. Revalidate them before the
        // new session starts in case recovery exposed a crashed helper.
        try await loadModels()
        try Task.checkCancellation()
        // Recovery can temporarily select a prior session's language pair.
        await utteranceProcessor.configure(mode: mode)
        let status = await dependencies.modelReporter.status(for: models.speechRecognition)
        return PreparedSessionInference(
            modelStatus: status,
            recoveryIssues: recoveryIssues
        )
    }

    func beginCapture(
        sessionID: UUID,
        inputDeviceID: AudioInputID?,
        mode: TranslationMode
    ) async throws -> StartedSessionCapture {
        try Task.checkCancellation()
        await utteranceProcessor.configure(mode: mode)
        do {
            try await dependencies.recordingStore.begin(sessionID: sessionID)
            try Task.checkCancellation()
            try await prepareTranscript(sessionID: sessionID, mode: mode)
            let stream = try await startCapture(inputDeviceID: inputDeviceID)
            return StartedSessionCapture(audioStream: stream)
        } catch {
            try? await dependencies.recordingStore.discard(sessionID: sessionID)
            throw error
        }
    }

    private func loadModels() async throws {
        try await modelPreparation.ensureReady()
    }

    private func replayRecoverableUtterances(
        excludingSessionID: UUID
    ) async -> [LiveSessionIssue] {
        await UtteranceRecoveryReplayer(
            dependencies: dependencies,
            processor: utteranceProcessor,
            excludedSessionID: excludingSessionID
        ).replay()
    }

    private func prepareTranscript(sessionID: UUID, mode: TranslationMode) async throws {
        await dependencies.audioProcessor.reset()
        await dependencies.vad.reset()
        try Task.checkCancellation()
        await dependencies.transcript.begin(
            sessionID: sessionID,
            at: Date(),
            configuration: TranscriptSessionConfiguration(
                kind: sessionKind,
                title: sessionTitle,
                sourceLanguage: mode.sourceLanguageTag,
                targetLanguage: mode.targetLanguageTag
            )
        )
        try Task.checkCancellation()
        guard let transcript = await dependencies.transcript.snapshot() else {
            throw CocoaError(.coderInvalidValue)
        }
        try await dependencies.transcriptStore.begin(transcript)
        try Task.checkCancellation()
    }

    private func startCapture(
        inputDeviceID: AudioInputID?
    ) async throws -> AsyncThrowingStream<AudioFrame, any Error> {
        do {
            let stream = try await dependencies.capture.startCapture(
                request: AudioCaptureRequest(deviceID: inputDeviceID)
            )
            try Task.checkCancellation()
            return stream
        } catch {
            await dependencies.capture.stopCapture()
            throw error
        }
    }
}
