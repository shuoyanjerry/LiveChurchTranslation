import Foundation
import SessionManagementAPI

extension InferenceModelPreparationCoordinator {
    public func currentModelPreparation() -> ModelPreparationSnapshot { snapshot }

    public func modelPreparationEvents() -> AsyncStream<ModelPreparationSnapshot> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeContinuation(id) }
            }
        }
    }

    public func ensureReady() async throws {
        try Task.checkCancellation()
        guard !isShutDown else { throw CancellationError() }
        if snapshot.isReady {
            let runtimesAreReady = await pipeline.runtimesAreReady()
            guard !isShutDown else { throw CancellationError() }
            if snapshot.isReady, runtimesAreReady { return }
        }
        startPreparationIfNeeded()
        guard !isShutDown, preparation != nil else { throw CancellationError() }
        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters[waiterID] = continuation
            }
        } onCancel: { [weak self] in
            guard let self else { return }
            Task { await self.cancelWaiter(waiterID) }
        }
    }
}
