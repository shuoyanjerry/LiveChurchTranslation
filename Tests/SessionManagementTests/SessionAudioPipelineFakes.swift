import AudioCaptureAPI
import AudioProcessingAPI
import Foundation
import VADAPI

enum SessionPipelineFakeError: LocalizedError, Sendable {
    case modelLoading
    case recognition
    case translation
    case storage
    case finalization

    var errorDescription: String? {
        switch self {
        case .modelLoading: "The fake ASR model failed to load."
        case .recognition: "The fake ASR runtime failed to recognize speech."
        case .translation: "The fake translation runtime failed."
        case .storage: "The fake transcript store failed."
        case .finalization: "The fake transcript could not be finalized."
        }
    }
}

actor FakeAudioCaptureProvider: AudioCaptureProvider {
    private let permission: AudioCapturePermission
    private let holdsPermissionRequest: Bool
    private let frames: [AudioFrame]
    private let holdsStreamOpen: Bool
    private var requests: [AudioCaptureRequest] = []
    private var continuation: AsyncThrowingStream<AudioFrame, any Error>.Continuation?
    private var permissionContinuation: CheckedContinuation<AudioCapturePermission, Never>?

    init(
        permission: AudioCapturePermission,
        frames: [AudioFrame],
        holdsPermissionRequest: Bool = false,
        holdsStreamOpen: Bool = false
    ) {
        self.permission = permission
        self.frames = frames
        self.holdsPermissionRequest = holdsPermissionRequest
        self.holdsStreamOpen = holdsStreamOpen
    }

    func authorizationStatus() -> AudioCapturePermission { permission }
    func requestPermission() async -> AudioCapturePermission {
        guard holdsPermissionRequest else { return permission }
        return await withCheckedContinuation { permissionContinuation = $0 }
    }
    func availableInputs() throws -> [AudioInputDevice] { [] }

    func startCapture(
        request: AudioCaptureRequest
    ) throws -> AsyncThrowingStream<AudioFrame, any Error> {
        requests.append(request)
        let pair = AsyncThrowingStream<AudioFrame, any Error>.makeStream()
        continuation = pair.continuation
        frames.forEach { pair.continuation.yield($0) }
        if !holdsStreamOpen { pair.continuation.finish() }
        return pair.stream
    }

    func stopCapture() {
        continuation?.finish()
        continuation = nil
    }
    func capturedRequests() -> [AudioCaptureRequest] { requests }
    func permissionRequestIsPending() -> Bool { permissionContinuation != nil }
    func completePermissionRequest() {
        permissionContinuation?.resume(returning: permission)
        permissionContinuation = nil
    }
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
    private let emitsOnlyOnFlush: Bool
    private var received: [ProcessedAudioFrame] = []
    private var hasEmitted = false

    init(emitsOnlyOnFlush: Bool = false) {
        self.emitsOnlyOnFlush = emitsOnlyOnFlush
    }

    func process(_ frame: ProcessedAudioFrame) -> [VoiceActivityEvent] {
        received.append(frame)
        guard !emitsOnlyOnFlush else { return [] }
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

    func flush() -> [VoiceActivityEvent] {
        guard emitsOnlyOnFlush, !hasEmitted, let first = received.first else { return [] }
        hasEmitted = true
        let samples = received.flatMap(\.samples)
        let endedAt = received.last.map { $0.timestamp + $0.duration } ?? first.timestamp
        let segment = SpeechSegment(
            sequenceNumber: 1,
            samples: samples,
            sampleRate: first.sampleRate,
            startedAt: first.timestamp,
            endedAt: endedAt,
            endReason: .endOfStream
        )
        return [.speechStarted(sequenceNumber: 1, at: first.timestamp), .speechEnded(segment)]
    }

    func reset() {
        received.removeAll(keepingCapacity: false)
        hasEmitted = false
    }
    func frames() -> [ProcessedAudioFrame] { received }
}
