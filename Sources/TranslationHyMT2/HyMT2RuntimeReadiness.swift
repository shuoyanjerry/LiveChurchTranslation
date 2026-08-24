import Foundation

struct HyMT2RuntimeReadiness: Sendable {
    let server: any LlamaServerControlling
    let transport: any LlamaServerTransport
    let configuration: HyMT2Configuration
    let timing: any HyMT2ReadinessTiming

    init(
        server: any LlamaServerControlling,
        transport: any LlamaServerTransport,
        configuration: HyMT2Configuration,
        timing: any HyMT2ReadinessTiming = ContinuousHyMT2ReadinessTiming()
    ) {
        self.server = server
        self.transport = transport
        self.configuration = configuration
        self.timing = timing
    }

    func wait(untilHealthy endpoint: LlamaServerEndpoint) async throws {
        let deadline = await timing.now() + max(configuration.startupTimeout, .zero)
        var lastMessage = "health endpoint unavailable"
        while true {
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

            let remaining = deadline - (await timing.now())
            guard remaining > .zero else { break }
            let pollDelay = min(max(configuration.healthPollInterval, .zero), remaining)
            if pollDelay > .zero {
                try await timing.sleep(for: pollDelay)
            } else {
                await Task.yield()
            }
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
