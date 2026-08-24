actor CleanupGate {
    private var isReleased = false
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var blockedObservers: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
            let observers = blockedObservers
            blockedObservers.removeAll()
            for observer in observers {
                observer.resume()
            }
        }
    }

    func waitUntilBlocked() async {
        guard continuations.isEmpty else { return }
        await withCheckedContinuation { continuation in
            blockedObservers.append(continuation)
        }
    }

    func release() {
        isReleased = true
        let pendingContinuations = continuations
        continuations.removeAll()
        for continuation in pendingContinuations {
            continuation.resume()
        }
    }
}

@MainActor
final class CompletionRecorder {
    private(set) var values: [Int] = []
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func append(_ value: Int) {
        values.append(value)
        let ready = waiters.filter { values.count >= $0.0 }
        waiters.removeAll { values.count >= $0.0 }
        for (_, continuation) in ready {
            continuation.resume()
        }
    }

    func waitUntilCount(_ count: Int) async {
        guard values.count < count else { return }
        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }
}

actor ShutdownEvents {
    enum Event: Equatable, Sendable {
        case importCancellation
        case sessionPreparation
        case modelPreparation
        case session
    }

    private var importCancellations = 0
    private var sessionPreparations = 0
    private var modelPreparationShutdowns = 0
    private var sessionShutdowns = 0
    private var events: [Event] = []

    func recordImportCancellation() {
        importCancellations += 1
        events.append(.importCancellation)
    }

    func recordModelPreparationShutdown() {
        modelPreparationShutdowns += 1
        events.append(.modelPreparation)
    }

    func recordSessionPreparation() {
        sessionPreparations += 1
        events.append(.sessionPreparation)
    }

    func recordSessionShutdown() {
        sessionShutdowns += 1
        events.append(.session)
    }

    func importCancellationCount() -> Int { importCancellations }
    func sessionShutdownCount() -> Int { sessionShutdowns }
    func sessionPreparationCount() -> Int { sessionPreparations }
    func modelPreparationShutdownCount() -> Int { modelPreparationShutdowns }
    func all() -> [Event] { events }
}
