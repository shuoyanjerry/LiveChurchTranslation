import Foundation
import ModelRuntimeAPI

public actor ModelRuntimeReporter: ModelRuntimeReporting {
    private var states: [ModelID: ModelRuntimeState] = [:]
    private var continuations: [UUID: AsyncStream<ModelRuntimeStatus>.Continuation] = [:]

    public init() {}

    public func status(for descriptor: ModelDescriptor) async -> ModelRuntimeStatus {
        ModelRuntimeStatus(descriptor: descriptor, state: states[descriptor.id] ?? .missing)
    }

    public func setState(_ state: ModelRuntimeState, for descriptor: ModelDescriptor) async {
        states[descriptor.id] = state
        let status = ModelRuntimeStatus(descriptor: descriptor, state: state)
        continuations.values.forEach { $0.yield(status) }
    }

    public func events() async -> AsyncStream<ModelRuntimeStatus> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in await self?.removeContinuation(id) }
            }
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
