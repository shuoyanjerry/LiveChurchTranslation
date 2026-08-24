import AudioCaptureAPI
import Foundation
import SettingsAPI

extension LiveSessionCoordinator {
    public func start(inputDeviceID: AudioInputID?) async {
        guard
            !Task.isCancelled,
            !isShuttingDown,
            !isActive,
            stopTask == nil,
            state.sessionID == nil
        else {
            return
        }
        let sessionID = UUID()
        guard await initializeSession(id: sessionID) else { return }
        guard !Task.isCancelled else {
            await stop()
            return
        }
        guard await authorizeCapture(for: sessionID) else { return }
        await prepareSession(inputDeviceID: inputDeviceID, sessionID: sessionID)
    }

    private func initializeSession(id: UUID) async -> Bool {
        isActive = true
        didStartCapture = false
        inferenceIsReady = false
        captureEndedBeforeInference = false
        terminalFailureMessage = nil
        hasUnrecoverableSessionFailure = false
        sentenceAudioTimelineAnchor = nil
        segmentQueue.removeAll()
        pendingUtterances.removeAll(keepingCapacity: false)
        unresolvedUtteranceCount = 0
        terminalRejectedSentenceCount = 0
        diskRecoveryMode = nil
        await utteranceProcessor.resetContext()
        guard isActive, !Task.isCancelled else {
            isActive = false
            return false
        }
        beginSession(id: id)
        return true
    }

    private func authorizeCapture(for sessionID: UUID) async -> Bool {
        let permission = await dependencies.capture.requestPermission()
        guard isActive, state.sessionID == sessionID else { return false }
        guard permission == .authorized else {
            await requestFailure(
                AudioCaptureError.permissionDenied.localizedDescription,
                stage: .preparation
            )
            return false
        }
        return true
    }

    private func prepareSession(
        inputDeviceID: AudioInputID?,
        sessionID: UUID
    ) async {
        do {
            let mode = try await sessionPreparer.loadMode()
            guard isActive, state.sessionID == sessionID else { return }
            state.setLanguages(source: mode.sourceLanguageTag, target: mode.targetLanguageTag)
            try await beginProcessing(
                mode: mode,
                sessionID: sessionID,
                inputDeviceID: inputDeviceID
            )
        } catch is CancellationError {
            guard isActive, state.sessionID == sessionID else { return }
            await requestFailure("会话准备已取消。", stage: .preparation)
        } catch {
            guard isActive, state.sessionID == sessionID else { return }
            await requestFailure(error.localizedDescription, stage: .preparation)
        }
    }

    private func beginProcessing(
        mode: TranslationMode,
        sessionID: UUID,
        inputDeviceID: AudioInputID?
    ) async throws {
        switch processingPolicy {
        case .boundedLive:
            state.transition(to: .preparingModel, message: "正在启动安全录音…")
            publishState()
            guard
                try await startCapture(
                    sessionID: sessionID,
                    inputDeviceID: inputDeviceID,
                    mode: mode,
                    inferenceReady: false
                )
            else { return }
            state.transition(
                to: .preparingModel,
                message: "录音中 · 正在准备本地模型…"
            )
            publishState()
            _ = try await prepareInference(mode: mode, sessionID: sessionID)
        case .completeImport:
            state.transition(to: .preparingModel, message: "正在准备本地模型…")
            publishState()
            guard try await prepareInference(mode: mode, sessionID: sessionID) else { return }
            _ = try await startCapture(
                sessionID: sessionID,
                inputDeviceID: inputDeviceID,
                mode: mode,
                inferenceReady: true
            )
        }
    }

    private func startCapture(
        sessionID: UUID,
        inputDeviceID: AudioInputID?,
        mode: TranslationMode,
        inferenceReady: Bool
    ) async throws -> Bool {
        sentenceAudioTimelineAnchor = nil
        let task = Task { [sessionPreparer] in
            try await sessionPreparer.beginCapture(
                sessionID: sessionID,
                inputDeviceID: inputDeviceID,
                mode: mode
            )
        }
        captureStartupTask = task
        let started = try await task.value
        captureStartupTask = nil
        guard isActive, state.sessionID == sessionID else {
            await dependencies.capture.stopCapture()
            return false
        }
        didStartCapture = true
        inferenceIsReady = inferenceReady
        state.markCaptureStarted(at: Date())
        captureTask = Task { [weak self] in
            await self?.consume(started.audioStream, sessionID: sessionID)
        }
        publishState()
        return true
    }

    private func prepareInference(mode: TranslationMode, sessionID: UUID) async throws -> Bool {
        let task = makePreparationTask(mode: mode, excludingSessionID: sessionID)
        preparationTask = task
        let prepared = try await task.value
        preparationTask = nil
        guard isActive, state.sessionID == sessionID else { return false }
        inferenceIsReady = true
        prepared.recoveryIssues.forEach { state.record($0) }
        state.setModelStatus(prepared.modelStatus)
        state.transition(to: .listening, message: captureStatusMessage(normal: "正在聆听"))
        publishState()
        startWorkerIfNeeded(sessionID: sessionID)
        if captureEndedBeforeInference {
            Task { [weak self] in await self?.stop() }
        }
        return true
    }

    private func beginSession(id: UUID) {
        state.begin(sessionID: id)
        publishState()
        observeModelStatus()
    }

}
