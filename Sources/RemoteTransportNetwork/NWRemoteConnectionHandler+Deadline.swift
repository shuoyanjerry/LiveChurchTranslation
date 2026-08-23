extension NWRemoteConnectionHandler {
    func startHTTPHandshakeDeadline() {
        handshakeTimeoutTask?.cancel()
        let timeout = limits.httpHandshakeTimeout
        handshakeTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.httpHandshakeDeadlineReached()
        }
    }

    func cancelHTTPHandshakeDeadline() {
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil
    }

    private func httpHandshakeDeadlineReached() async {
        guard !closed else { return }
        guard case .http = mode else { return }
        await close()
    }
}
