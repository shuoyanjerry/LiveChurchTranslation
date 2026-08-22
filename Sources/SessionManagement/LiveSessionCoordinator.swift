import AudioCaptureAPI
import Foundation
import ModelRuntimeAPI
import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

public actor LiveSessionCoordinator: LiveSessionController {
    let dependencies: LiveSessionDependencies
    let utteranceProcessor: UtteranceProcessor
    let sessionPreparer: SessionPreparer
    let sessionFinalizer: SessionFinalizer
    var state = LiveSessionStateMachine()
    var captureTask: Task<Void, Never>?
    var workerTask: Task<Void, Never>?
    var modelTask: Task<Void, Never>?
    var preparationTask: Task<PreparedSession, any Error>?
    var stopTask: Task<Void, Never>?
    var segmentQueue: [PendingUtteranceRecord] = []
    var pendingUtterances: [PendingUtterance] = []
    var eventHub = SessionEventHub()
    var isActive = false
    var didStartCapture = false
    var terminalFailureMessage: String?
    var unsavedTranscripts: [UUID: TranscriptSession] = [:]

    public init(
        dependencies: LiveSessionDependencies,
        models: SessionModelDescriptors
    ) {
        self.dependencies = dependencies
        let processor = UtteranceProcessor(dependencies: dependencies)
        utteranceProcessor = processor
        sessionPreparer = SessionPreparer(
            dependencies: dependencies,
            models: models,
            utteranceProcessor: processor
        )
        sessionFinalizer = SessionFinalizer(dependencies: dependencies)
    }
}

extension LiveSessionCoordinator {
    public func start(inputDeviceID: AudioInputID?) async {
        guard !isActive, stopTask == nil, state.sessionID == nil else { return }
        let sessionID = UUID()
        isActive = true
        didStartCapture = false
        terminalFailureMessage = nil
        pendingUtterances.removeAll(keepingCapacity: false)
        await utteranceProcessor.resetContext()
        beginSession(id: sessionID)
        let permission = await dependencies.capture.requestPermission()
        guard isActive, state.sessionID == sessionID else { return }
        guard permission == .authorized else {
            await requestFailure(
                AudioCaptureError.permissionDenied.localizedDescription,
                stage: .preparation
            )
            return
        }
        state.transition(to: .preparingModel, message: "Preparing the Mandarin model…")
        publishState()
        let preparation = makePreparationTask(
            sessionID: sessionID,
            inputDeviceID: inputDeviceID
        )
        preparationTask = preparation
        do {
            let prepared = try await preparation.value
            guard await activate(prepared, sessionID: sessionID) else { return }
        } catch is CancellationError {
            guard isActive, state.sessionID == sessionID else { return }
            await requestFailure("Session preparation was cancelled.", stage: .preparation)
        } catch {
            guard isActive, state.sessionID == sessionID else { return }
            await requestFailure(error.localizedDescription, stage: .preparation)
        }
    }

    private func activate(_ prepared: PreparedSession, sessionID: UUID) async -> Bool {
        guard isActive, state.sessionID == sessionID else {
            await dependencies.capture.stopCapture()
            return false
        }
        preparationTask = nil
        didStartCapture = true
        prepared.recoveryIssues.forEach { state.record($0) }
        state.setModelStatus(prepared.modelStatus)
        state.transition(to: .listening, message: "Listening")
        publishState()
        captureTask = Task { [weak self] in
            await self?.consume(prepared.audioStream, sessionID: sessionID)
        }
        return true
    }

    private func beginSession(id: UUID) {
        state.begin(sessionID: id)
        publishState()
        observeModelStatus()
    }

    private func makePreparationTask(
        sessionID: UUID,
        inputDeviceID: AudioInputID?
    ) -> Task<PreparedSession, any Error> {
        Task { [sessionPreparer] in
            try await sessionPreparer.prepare(
                sessionID: sessionID,
                inputDeviceID: inputDeviceID
            )
        }
    }
}

extension LiveSessionCoordinator {
    public func stop() async {
        if let stopTask {
            await stopTask.value
            return
        }
        guard let sessionID = state.sessionID else { return }
        isActive = false
        state.transition(to: .stopping, message: "Finishing the current sentence…")
        publishState()
        preparationTask?.cancel()
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.performStop(sessionID: sessionID)
        }
        stopTask = task
        await task.value
    }

    public func currentSnapshot() async -> LiveSessionSnapshot {
        state.snapshot
    }

    public func events() async -> AsyncStream<LiveSessionEvent> {
        eventHub.stream(initial: state.snapshot) { [weak self] id in
            Task { await self?.removeContinuation(id) }
        }
    }

    func publishState() { publish(.stateChanged(state.snapshot)) }
    private func receiveModelStatus(_ status: ModelRuntimeStatus) {
        guard state.sessionID != nil else { return }
        state.receive(status)
        publishState()
    }
    func publish(_ event: LiveSessionEvent) { eventHub.publish(event) }
    private func removeContinuation(_ id: UUID) { eventHub.remove(id) }

    private func observeModelStatus() {
        modelTask = Task { [weak self, reporter = dependencies.modelReporter] in
            for await status in await reporter.events() {
                await self?.receiveModelStatus(status)
            }
        }
    }
}
