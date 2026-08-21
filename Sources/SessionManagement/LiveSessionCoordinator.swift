import AudioCaptureAPI
import Foundation
import ModelRuntimeAPI
import SessionManagementAPI
import VADAPI

public actor LiveSessionCoordinator: LiveSessionController {
    let dependencies: LiveSessionDependencies
    let utteranceProcessor: UtteranceProcessor
    private let sessionPreparer: SessionPreparer
    let sessionFinalizer: SessionFinalizer
    var state = LiveSessionStateMachine()
    private var captureTask: Task<Void, Never>?
    var workerTask: Task<Void, Never>?
    private var modelTask: Task<Void, Never>?
    var segmentQueue: [SpeechSegment] = []
    var eventHub = SessionEventHub()
    var isActive = false

    public init(
        dependencies: LiveSessionDependencies,
        models: SessionModelDescriptors
    ) {
        self.dependencies = dependencies
        utteranceProcessor = UtteranceProcessor(dependencies: dependencies)
        sessionPreparer = SessionPreparer(
            dependencies: dependencies,
            models: models
        )
        sessionFinalizer = SessionFinalizer(dependencies: dependencies)
    }

    public func start(inputDeviceID: AudioInputID?) async {
        guard !isActive else { return }
        let sessionID = UUID()
        isActive = true
        state.begin(sessionID: sessionID)
        publishState()
        modelTask = Task { [weak self, reporter = dependencies.modelReporter] in
            for await status in await reporter.events() {
                await self?.receiveModelStatus(status)
            }
        }

        do {
            state.transition(to: .preparingModel, message: "Preparing the Mandarin model…")
            publishState()
            let prepared = try await sessionPreparer.prepare(
                sessionID: sessionID,
                inputDeviceID: inputDeviceID
            )
            state.setModelStatus(prepared.modelStatus)
            state.transition(to: .listening, message: "Listening")
            publishState()
            captureTask = Task { [weak self] in
                await self?.consume(prepared.audioStream, sessionID: sessionID)
            }
        } catch {
            await failSession(error.localizedDescription)
        }
    }

    public func stop() async {
        guard isActive, let sessionID = state.sessionID else { return }
        isActive = false
        state.transition(to: .stopping, message: "Finishing the current sentence…")
        publishState()
        captureTask?.cancel()
        captureTask = nil
        await dependencies.capture.stopCapture()

        for event in await dependencies.vad.flush() {
            handle(event, sessionID: sessionID)
        }
        let worker = workerTask
        await worker?.value
        await finishSession(sessionID: sessionID)
    }

    public func currentSnapshot() async -> LiveSessionSnapshot {
        state.snapshot
    }

    public func events() async -> AsyncStream<LiveSessionEvent> {
        eventHub.stream(initial: state.snapshot) { [weak self] id in
            Task { await self?.removeContinuation(id) }
        }
    }

    func finishSession(sessionID: UUID) async {
        await sessionFinalizer.finish(sessionID: sessionID)
        segmentQueue.removeAll(keepingCapacity: false)
        state.finish()
        modelTask?.cancel()
        modelTask = nil
        publishState()
    }

    func failSession(_ message: String) async {
        isActive = false
        await sessionFinalizer.fail(message)
        modelTask?.cancel()
        modelTask = nil
        state.fail(message)
        publishState()
        publish(.recoverableError(message))
    }

    func publishState() { publish(.stateChanged(state.snapshot)) }
    private func receiveModelStatus(_ status: ModelRuntimeStatus) {
        state.receive(status)
        publishState()
    }
    func publish(_ event: LiveSessionEvent) { eventHub.publish(event) }
    private func removeContinuation(_ id: UUID) { eventHub.remove(id) }
}
