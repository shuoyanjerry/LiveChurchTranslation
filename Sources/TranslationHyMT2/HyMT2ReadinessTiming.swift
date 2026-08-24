import Foundation

protocol HyMT2ReadinessTiming: Sendable {
    func now() async -> Duration
    func sleep(for duration: Duration) async throws
}

struct ContinuousHyMT2ReadinessTiming: HyMT2ReadinessTiming {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant

    init() {
        origin = clock.now
    }

    func now() -> Duration {
        origin.duration(to: clock.now)
    }

    func sleep(for duration: Duration) async throws {
        try await clock.sleep(for: duration)
    }
}
