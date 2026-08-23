import AudioCaptureAPI
import Foundation
import ModelRuntimeAPI
import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

enum SessionProcessingPolicy: Sendable {
    case boundedLive
    case completeImport

    init(sessionKind: TranscriptSessionKind) {
        self = sessionKind == .importedAudio ? .completeImport : .boundedLive
    }

    var requiresCompleteCapture: Bool { self == .completeImport }
}

public actor LiveSessionCoordinator: LiveSessionController {
    let dependencies: LiveSessionDependencies
    let utteranceProcessor: UtteranceProcessor
    let sessionPreparer: SessionPreparer
    let sessionFinalizer: SessionFinalizer
    let processingPolicy: SessionProcessingPolicy
    var state = LiveSessionStateMachine()
    var captureTask: Task<Void, Never>?
    var workerTask: Task<Void, Never>?
    var modelTask: Task<Void, Never>?
    var captureStartupTask: Task<StartedSessionCapture, any Error>?
    var preparationTask: Task<PreparedSessionInference, any Error>?
    var stopTask: Task<Void, Never>?
    var segmentQueue = PendingUtteranceQueue()
    var pendingUtterances: [PendingUtterance] = []
    var unresolvedUtteranceCount = 0
    var diskRecoveryMode: DiskRecoveryMode?
    var eventHub = SessionEventHub()
    var isActive = false
    var didStartCapture = false
    var inferenceIsReady = false
    var captureEndedBeforeInference = false
    var terminalFailureMessage: String?
    var unsavedTranscripts: [UUID: TranscriptSession] = [:]

    public init(
        dependencies: LiveSessionDependencies,
        models: SessionModelDescriptors,
        sessionKind: TranscriptSessionKind = .live,
        sessionTitle: String? = nil
    ) {
        self.dependencies = dependencies
        processingPolicy = SessionProcessingPolicy(sessionKind: sessionKind)
        let processor = UtteranceProcessor(dependencies: dependencies)
        utteranceProcessor = processor
        sessionPreparer = SessionPreparer(
            dependencies: dependencies,
            models: models,
            utteranceProcessor: processor,
            sessionKind: sessionKind,
            sessionTitle: sessionTitle
        )
        sessionFinalizer = SessionFinalizer(dependencies: dependencies)
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
        captureStartupTask?.cancel()
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

    func observeModelStatus() {
        modelTask = Task { [weak self, reporter = dependencies.modelReporter] in
            for await status in await reporter.events() {
                await self?.receiveModelStatus(status)
            }
        }
    }
}
