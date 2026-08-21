import AudioCaptureAPI
import Foundation
import ModelRuntimeAPI

struct PreparedSession: Sendable {
    let audioStream: AsyncThrowingStream<AudioFrame, any Error>
    let modelStatus: ModelRuntimeStatus
}

struct SessionPreparer: Sendable {
    let dependencies: LiveSessionDependencies
    let models: SessionModelDescriptors

    func prepare(sessionID: UUID, inputDeviceID: AudioInputID?) async throws -> PreparedSession {
        let permission = await dependencies.capture.requestPermission()
        guard permission == .authorized else { throw AudioCaptureError.permissionDenied }

        async let asrLocation = dependencies.modelDownloader.ensureAvailable(
            models.speechRecognition
        )
        async let translationLocation = dependencies.modelDownloader.ensureAvailable(
            models.translation
        )
        let locations = try await (asrLocation, translationLocation)

        await dependencies.modelReporter.setState(.loading, for: models.speechRecognition)
        try await dependencies.asr.loadModel(at: locations.0)
        await dependencies.modelReporter.setState(.ready, for: models.speechRecognition)
        await dependencies.modelReporter.setState(.loading, for: models.translation)
        try await dependencies.translator.loadModel(at: locations.1)
        await dependencies.modelReporter.setState(.ready, for: models.translation)

        await dependencies.audioProcessor.reset()
        await dependencies.vad.reset()
        await dependencies.transcript.begin(sessionID: sessionID, at: Date())
        guard let transcript = await dependencies.transcript.snapshot() else {
            throw CocoaError(.coderInvalidValue)
        }
        try await dependencies.transcriptStore.begin(transcript)
        let stream = try await dependencies.capture.startCapture(
            request: AudioCaptureRequest(deviceID: inputDeviceID)
        )
        let status = await dependencies.modelReporter.status(for: models.speechRecognition)
        return PreparedSession(audioStream: stream, modelStatus: status)
    }
}
