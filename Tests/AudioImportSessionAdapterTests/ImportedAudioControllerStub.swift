import AudioCaptureAPI
import SessionManagementAPI

actor ImportedAudioControllerStub: LiveSessionController {
    private let holdEvents: Bool
    private let holdStart: Bool
    private var eventCalls = 0
    private var startCalls = 0
    private var stopCalls = 0
    private var eventWaiters: [CheckedContinuation<Void, Never>] = []
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var streamContinuation: AsyncStream<LiveSessionEvent>.Continuation?

    init(holdEvents: Bool = false, holdStart: Bool = false) {
        self.holdEvents = holdEvents
        self.holdStart = holdStart
    }

    func events() async -> AsyncStream<LiveSessionEvent> {
        eventCalls += 1
        if holdEvents {
            await withCheckedContinuation { eventWaiters.append($0) }
        }
        let (stream, continuation) = AsyncStream.makeStream(of: LiveSessionEvent.self)
        streamContinuation = continuation
        return stream
    }

    func start(inputDeviceID _: AudioInputID?) async {
        startCalls += 1
        if holdStart {
            await withCheckedContinuation { startWaiters.append($0) }
        }
    }

    func stop() {
        stopCalls += 1
        streamContinuation?.finish()
    }

    func currentSnapshot() -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: nil,
            phase: .idle,
            transcript: [],
            modelStatus: nil,
            statusMessage: ""
        )
    }

    func releaseEvents() {
        let waiters = eventWaiters
        eventWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func releaseStart() {
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func eventsCallCount() -> Int { eventCalls }
    func startCallCount() -> Int { startCalls }
    func stopCallCount() -> Int { stopCalls }
}
