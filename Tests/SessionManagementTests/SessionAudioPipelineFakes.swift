import ASRAPI
import AudioCaptureAPI
import AudioProcessingAPI
import Foundation
import TranslationAPI
import VADAPI

enum SessionPipelineFakeError: LocalizedError, Sendable {
    case translation
    case storage

    var errorDescription: String? {
        switch self {
        case .translation: "The fake translation runtime failed."
        case .storage: "The fake transcript store failed."
        }
    }
}

actor FakeAudioCaptureProvider: AudioCaptureProvider {
    private let permission: AudioCapturePermission
    private let frames: [AudioFrame]
    private var requests: [AudioCaptureRequest] = []

    init(permission: AudioCapturePermission, frames: [AudioFrame]) {
        self.permission = permission
        self.frames = frames
    }

    func authorizationStatus() -> AudioCapturePermission { permission }
    func requestPermission() -> AudioCapturePermission { permission }
    func availableInputs() throws -> [AudioInputDevice] { [] }

    func startCapture(
        request: AudioCaptureRequest
    ) throws -> AsyncThrowingStream<AudioFrame, any Error> {
        requests.append(request)
        return AsyncThrowingStream { continuation in
            frames.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func stopCapture() {}
    func capturedRequests() -> [AudioCaptureRequest] { requests }
}

actor FakeAudioProcessor: AudioProcessor {
    private var received: [AudioFrame] = []

    func process(_ frame: AudioFrame) -> ProcessedAudioFrame {
        received.append(frame)
        return ProcessedAudioFrame(
            samples: frame.samples,
            sampleRate: frame.sampleRate,
            timestamp: frame.timestamp
        )
    }

    func reset() { received.removeAll() }
    func frames() -> [AudioFrame] { received }
}

actor FakeSegmentingVAD: VoiceActivityDetector {
    private var received: [ProcessedAudioFrame] = []
    private var hasEmitted = false

    func process(_ frame: ProcessedAudioFrame) -> [VoiceActivityEvent] {
        received.append(frame)
        guard !hasEmitted else { return [] }
        hasEmitted = true
        let end = frame.timestamp + frame.duration
        let segment = SpeechSegment(
            sequenceNumber: 1,
            samples: frame.samples,
            sampleRate: frame.sampleRate,
            startedAt: frame.timestamp,
            endedAt: end,
            endReason: .trailingSilence
        )
        return [
            .speechStarted(sequenceNumber: 1, at: frame.timestamp),
            .speechEnded(segment),
        ]
    }

    func flush() -> [VoiceActivityEvent] { [] }
    func reset() { hasEmitted = false }
    func frames() -> [ProcessedAudioFrame] { received }
}

actor FakeMandarinASRProvider: ASRProvider {
    nonisolated let identifier = "fake-mandarin-asr"
    private let text: String
    private var requests: [ASRRequest] = []

    init(text: String) { self.text = text }

    func loadModel(at _: URL) {}

    func transcribe(_ request: ASRRequest) -> RecognizedUtterance {
        requests.append(request)
        return RecognizedUtterance(
            sourceSegmentID: request.segment.id,
            text: text,
            confidence: 0.99,
            startedAt: request.segment.startedAt,
            endedAt: request.segment.endedAt
        )
    }

    func unloadModel() {}
    func receivedRequests() -> [ASRRequest] { requests }
}

actor FakeHyTranslationProvider: TranslationProvider {
    nonisolated let identifier = "fake-hy-mt2"
    private let shouldFail: Bool
    private var requests: [TranslationRequest] = []

    init(shouldFail: Bool) { self.shouldFail = shouldFail }
    func loadModel(at _: URL) {}

    func translate(_ request: TranslationRequest) throws -> TranslationResult {
        requests.append(request)
        if shouldFail { throw SessionPipelineFakeError.translation }
        return TranslationResult(
            requestID: request.id,
            sourceText: request.sourceText,
            targetText: "We are justified by faith; this is grace.",
            duration: .milliseconds(35)
        )
    }

    func shutdown() {}
    func receivedRequests() -> [TranslationRequest] { requests }
}
