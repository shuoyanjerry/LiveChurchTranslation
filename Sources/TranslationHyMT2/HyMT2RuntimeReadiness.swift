import Foundation

struct HyMT2RuntimeReadiness: Sendable {
    let server: any LlamaServerControlling
    let transport: any LlamaServerTransport
    let configuration: HyMT2Configuration

    func wait(untilHealthy endpoint: LlamaServerEndpoint) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: configuration.startupTimeout)
        var lastMessage = "health endpoint unavailable"
        while clock.now < deadline {
            try Task.checkCancellation()
            guard await server.isRunning() else { throw HyMT2Error.serverTerminated }
            do {
                try await transport.checkHealth(
                    at: endpoint,
                    timeout: configuration.requestTimeout
                )
                return
            } catch {
                lastMessage = error.localizedDescription
            }
            try await Task.sleep(for: configuration.healthPollInterval)
        }
        throw HyMT2Error.startupTimedOut(lastMessage)
    }
}

enum HyMT2ErrorNormalizer {
    static func normalized(_ error: Error) -> Error {
        if let error = error as? HyMT2Error { return error }
        if error is CancellationError { return error }
        return HyMT2Error.transportFailure(error.localizedDescription)
    }
}
