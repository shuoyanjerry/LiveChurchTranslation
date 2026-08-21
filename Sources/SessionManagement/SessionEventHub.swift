import Foundation
import SessionManagementAPI

struct SessionEventHub {
    private var continuations: [UUID: AsyncStream<LiveSessionEvent>.Continuation] = [:]

    mutating func stream(
        initial: LiveSessionSnapshot,
        onTermination: @escaping @Sendable (UUID) -> Void
    ) -> AsyncStream<LiveSessionEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(.stateChanged(initial))
            continuation.onTermination = { _ in onTermination(id) }
        }
    }

    func publish(_ event: LiveSessionEvent) {
        continuations.values.forEach { $0.yield(event) }
    }

    mutating func remove(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}
