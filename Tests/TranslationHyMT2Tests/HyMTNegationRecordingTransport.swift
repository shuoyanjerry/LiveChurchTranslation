import Foundation
@testable import TranslationHyMT2

actor HyMTNegationRecordingTransport: LlamaServerTransport {
    private let base: any LlamaServerTransport
    private var observations: [HyMTNegationCompletionObservation] = []

    init(base: any LlamaServerTransport) {
        self.base = base
    }

    func checkHealth(
        at endpoint: LlamaServerEndpoint,
        timeout: TimeInterval
    ) async throws {
        try await base.checkHealth(at: endpoint, timeout: timeout)
    }

    func complete(
        _ request: LlamaCompletionRequest,
        at endpoint: LlamaServerEndpoint,
        timeout: TimeInterval
    ) async throws -> String {
        let clock = ContinuousClock()
        let started = clock.now
        do {
            let output = try await base.complete(request, at: endpoint, timeout: timeout)
            observations.append(
                HyMTNegationCompletionObservation(
                    output: output,
                    latencySeconds: seconds(started.duration(to: clock.now))
                )
            )
            return output
        } catch {
            observations.append(
                HyMTNegationCompletionObservation(
                    output: nil,
                    latencySeconds: seconds(started.duration(to: clock.now))
                )
            )
            throw error
        }
    }

    func reset() {
        observations.removeAll(keepingCapacity: true)
    }

    func takeObservations() -> [HyMTNegationCompletionObservation] {
        defer { observations.removeAll(keepingCapacity: true) }
        return observations
    }

    private func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
