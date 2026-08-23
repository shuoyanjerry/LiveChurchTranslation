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
        if snapshot.isReady {
            let runtimesAreReady = await pipeline.runtimesAreReady()
            if snapshot.isReady, runtimesAreReady { return }
        }
        startPreparationIfNeeded()
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
