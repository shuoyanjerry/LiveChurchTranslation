import AudioCaptureAPI
import Foundation
import ModelRuntimeAPI
import SessionManagementAPI

struct PreparedSession: Sendable {
    let audioStream: AsyncThrowingStream<AudioFrame, any Error>
    let modelStatus: ModelRuntimeStatus
    let recoveryIssues: [LiveSessionIssue]
}

struct SessionPreparer: Sendable {
    let dependencies: LiveSessionDependencies
    let models: SessionModelDescriptors
    let utteranceProcessor: UtteranceProcessor

    func prepare(sessionID: UUID, inputDeviceID: AudioInputID?) async throws -> PreparedSession {
        try Task.checkCancellation()
        try await loadModels()
        let recoveryIssues = await replayRecoverableUtterances()
        try await prepareTranscript(sessionID: sessionID)
        let stream = try await startCapture(inputDeviceID: inputDeviceID)
        let status = await dependencies.modelReporter.status(for: models.speechRecognition)
        return PreparedSession(
            audioStream: stream,
            modelStatus: status,
            recoveryIssues: recoveryIssues
        )
    }

    private func loadModels() async throws {
        async let asrLocation = dependencies.modelDownloader.ensureAvailable(
            models.speechRecognition
        )
        async let translationLocation = dependencies.modelDownloader.ensureAvailable(
            models.translation
        )
        let locations = try await (asrLocation, translationLocation)
        try Task.checkCancellation()

        await dependencies.modelReporter.setState(.loading, for: models.speechRecognition)
        try await dependencies.asr.loadModel(at: locations.0)
        try Task.checkCancellation()
        await dependencies.modelReporter.setState(.ready, for: models.speechRecognition)
        await dependencies.modelReporter.setState(.loading, for: models.translation)
        try await dependencies.translator.loadModel(at: locations.1)
        try Task.checkCancellation()
        await dependencies.modelReporter.setState(.ready, for: models.translation)
    }

    private func replayRecoverableUtterances() async -> [LiveSessionIssue] {
        await UtteranceRecoveryReplayer(
            dependencies: dependencies,
            processor: utteranceProcessor
        ).replay()
    }

    private func prepareTranscript(sessionID: UUID) async throws {
        await dependencies.audioProcessor.reset()
        await dependencies.vad.reset()
        try Task.checkCancellation()
        await dependencies.transcript.begin(sessionID: sessionID, at: Date())
        try Task.checkCancellation()
        guard let transcript = await dependencies.transcript.snapshot() else {
            throw CocoaError(.coderInvalidValue)
        }
        try await dependencies.transcriptStore.begin(transcript)
        try Task.checkCancellation()
    }

    func cancel() async {
        await dependencies.modelDownloader.cancelDownload(for: models.speechRecognition.id)
        await dependencies.modelDownloader.cancelDownload(for: models.translation.id)
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
