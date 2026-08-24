import Foundation

enum HyMT2AttemptPhase: String, Equatable, Sendable {
    case initial
    case strictRetry
    case safetyFallback
}

enum HyMT2AttemptOutcome: String, Equatable, Sendable {
    case accepted
    case validationRejected
    case transportFailed
    case cancelled
}

struct HyMT2AttemptObservation: Equatable, Sendable {
    let requestID: UUID
    let phase: HyMT2AttemptPhase
    let outcome: HyMT2AttemptOutcome
}

protocol HyMT2AttemptObserving: Sendable {
    func record(_ observation: HyMT2AttemptObservation) async
}

struct HyMT2NoOpAttemptObserver: HyMT2AttemptObserving {
    func record(_: HyMT2AttemptObservation) async {}
}
