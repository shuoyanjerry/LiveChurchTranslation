import Foundation
import RemoteTransportAPI

actor DelayedFailureThenSuccessTransport: RemoteTransportServing {
    private var starts = 0
    private var firstStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstFailureRelease: CheckedContinuation<Void, Never>?

    func start(configuration: RemoteTransportConfiguration) async throws -> RemoteEndpoint {
        starts += 1
        if starts == 1 {
            let waiters = firstStartWaiters
            firstStartWaiters.removeAll()
            waiters.forEach { $0.resume() }
            await withCheckedContinuation { continuation in
                firstFailureRelease = continuation
            }
            throw RemoteTransportLifecycleError.localNetworkPermissionDenied
        }
        return RemoteEndpoint(
            baseURL: URL(string: "http://\(configuration.advertisedHostName):8123")!,
            port: 8_123
        )
    }

    func waitUntilFirstStartBegins() async {
        guard starts == 0 else { return }
        await withCheckedContinuation { continuation in
            firstStartWaiters.append(continuation)
        }
    }

    func releaseFirstFailure() {
        firstFailureRelease?.resume()
        firstFailureRelease = nil
    }

    func stop() {}
    func status() -> RemoteTransportStatus { .stopped }
    func events() -> AsyncStream<RemoteTransportEvent> {
        AsyncStream { $0.finish() }
    }
    func startCount() -> Int { starts }
}
