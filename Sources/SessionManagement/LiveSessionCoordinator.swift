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
    var transcribesOnly: Bool { self == .completeImport }
    var allowsTranslatedRecovery: Bool { self == .boundedLive }

    var modelPreparationScope: InferenceModelPreparationScope {
        transcribesOnly ? .speechRecognition : .speechAndTranslation
    }
}

public actor LiveSessionCoordinator: LiveSessionController {
    let dependencies: LiveSessionDependencies
    let utteranceProcessor: UtteranceProcessor
    let modelPreparation: InferenceModelPreparationCoordinator
    let sessionPreparer: SessionPreparer
    let sessionFinalizer: SessionFinalizer
    let processingPolicy: SessionProcessingPolicy
    let sentenceVisibilityClock: any SentenceVisibilityClock
    var state = LiveSessionStateMachine()
    var captureTask: Task<Void, Never>?
    var workerTask: Task<Void, Never>?
    var modelTask: Task<Void, Never>?
    var captureStartupTask: Task<StartedSessionCapture, any Error>?
    var preparationTask: Task<PreparedSessionInference, any Error>?
    var stopTask: Task<Void, Never>?
    var shutdownTask: Task<Void, Never>?
    var isShuttingDown = false
    var segmentQueue = PendingUtteranceQueue()
    var pendingUtterances: [PendingUtterance] = []
    var unresolvedUtteranceCount = 0
    var terminalRejectedSentenceCount = 0
    var diskRecoveryMode: DiskRecoveryMode?
    var eventHub = SessionEventHub()
    var isActive = false
    var didStartCapture = false
    var inferenceIsReady = false
    var captureEndedBeforeInference = false
    var terminalFailureMessage: String?
    var hasUnrecoverableSessionFailure = false
    var unsavedTranscripts: [UUID: TranscriptSession] = [:]
    var sentenceAudioTimelineAnchor: SentenceAudioTimelineAnchor?

    public init(
        dependencies: LiveSessionDependencies,
        models: SessionModelDescriptors,
        modelPreparation: InferenceModelPreparationCoordinator? = nil,
        sessionKind: TranscriptSessionKind = .live,
        sessionTitle: String? = nil
    ) {
        self.init(
            dependencies: dependencies,
            models: models,
            modelPreparation: modelPreparation,
            sessionKind: sessionKind,
            sessionTitle: sessionTitle,
            sentenceVisibilityClock: ContinuousSentenceVisibilityClock()
        )
    }

    init(
        dependencies: LiveSessionDependencies,
        models: SessionModelDescriptors,
        modelPreparation: InferenceModelPreparationCoordinator? = nil,
        sessionKind: TranscriptSessionKind = .live,
        sessionTitle: String? = nil,
        sentenceVisibilityClock: any SentenceVisibilityClock
    ) {
        self.dependencies = dependencies
        self.sentenceVisibilityClock = sentenceVisibilityClock
        let processingPolicy = SessionProcessingPolicy(sessionKind: sessionKind)
        self.processingPolicy = processingPolicy
        let processor = UtteranceProcessor(dependencies: dependencies)
        let modelPreparation =
            modelPreparation
            ?? InferenceModelPreparationCoordinator(
                modelDownloader: dependencies.modelDownloader,
                modelReporter: dependencies.modelReporter,
                asr: dependencies.asr,
                translator: dependencies.translator,
                models: models,
                scope: processingPolicy.modelPreparationScope
            )
        utteranceProcessor = processor
        self.modelPreparation = modelPreparation
        sessionPreparer = SessionPreparer(
            dependencies: dependencies,
            models: models,
            modelPreparation: modelPreparation,
            utteranceProcessor: processor,
            sessionKind: sessionKind,
            allowsTranslatedRecovery: processingPolicy.allowsTranslatedRecovery,
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
        guard let sessionID = state.sessionID else {
            guard isActive else { return }
            isActive = false
            captureStartupTask?.cancel()
            preparationTask?.cancel()
            return
        }
        isActive = false
        state.transition(to: .stopping, message: "正在完成当前片段…")
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
            guard let self else { return }
            Task { await self.removeContinuation(id) }
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
