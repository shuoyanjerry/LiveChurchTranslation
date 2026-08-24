import Foundation
import SessionManagementAPI

extension InferenceModelPreparationCoordinator {
    public func prepareModels() async {
        guard !isShutDown else { return }
        let active = automaticPreparation ?? startAutomaticPreparation()
        await active.task.value
        clearAutomaticPreparation(matching: active.token)
    }

    public func retryModelPreparation() async {
        guard !isShutDown else { return }
        if let active = automaticPreparation {
            await active.task.value
            clearAutomaticPreparation(matching: active.token)
        }
        guard !isShutDown, !snapshot.isReady else { return }
        let active = startAutomaticPreparation()
        await active.task.value
        clearAutomaticPreparation(matching: active.token)
    }

    public func shutdownModelPreparation() async {
        guard !isShutDown else {
            await waitForActivePreparationToFinish()
            return
        }
        isShutDown = true
        automaticPreparation?.task.cancel()
        preparation?.task.cancel()
        await pipeline.cancelDownloads()
        await waitForActivePreparationToFinish()
    }

    private func startAutomaticPreparation() -> AutomaticModelPreparation {
        let token = UUID()
        let coordinator = self
        let task = Task<Void, Never> {
            await coordinator.performAutomaticPreparation()
        }
        let active = AutomaticModelPreparation(token: token, task: task)
        automaticPreparation = active
        return active
    }

    private func performAutomaticPreparation() async {
        for attemptIndex in 0...retryDelays.count {
            guard !Task.isCancelled, !isShutDown else { return }
            do {
                try await ensureReady()
                return
            } catch is CancellationError {
                return
            } catch {
                guard attemptIndex < retryDelays.count else { return }
                publishRetry(attemptIndex: attemptIndex)
                try? await Task.sleep(for: retryDelays[attemptIndex])
            }
        }
    }

    private func publishRetry(attemptIndex: Int) {
        let nextAttempt = attemptIndex + 2
        publish(
            ModelPreparationSnapshot(
                phase: .retrying(attempt: nextAttempt),
                message: "模型准备暂时中断，即将自动重试（\(nextAttempt)/\(retryDelays.count + 1)）…"
            )
        )
    }

    private func waitForActivePreparationToFinish() async {
        let activePreparation = preparation
        let automatic = automaticPreparation
        await activePreparation?.task.value
        await automatic?.task.value
        if let activePreparation, preparation?.token == activePreparation.token {
            preparation = nil
        }
        if let automatic {
            clearAutomaticPreparation(matching: automatic.token)
        }
        let pending = waiters.values
        waiters.removeAll()
        pending.forEach { $0.resume(throwing: CancellationError()) }
    }

    private func clearAutomaticPreparation(matching token: UUID) {
        guard automaticPreparation?.token == token else { return }
        automaticPreparation = nil
    }
}

struct AutomaticModelPreparation: Sendable {
    let token: UUID
    let task: Task<Void, Never>
}
