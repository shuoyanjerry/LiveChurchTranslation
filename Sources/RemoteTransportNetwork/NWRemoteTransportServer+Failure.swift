import Foundation
@preconcurrency import Network
import RemoteTransportAPI

extension NWRemoteTransportServer {
    func handleListenerFailure(_ error: NWError) async {
        if NWLocalNetworkPermissionDenial.matches(error) {
            await handleLocalNetworkPermissionDenial()
        } else if startContinuation != nil {
            failStart(error.localizedDescription)
        } else {
            await failRunningServer(error.localizedDescription)
        }
    }

    func handleLocalNetworkPermissionDenial() async {
        if startContinuation != nil {
            failStart(.localNetworkPermissionDenied)
        } else {
            await failRunningServerForLocalNetworkPermission()
        }
    }

    func failRunningServer(_ message: String) async {
        await stopRunningServer(status: .failed(message: String(message.prefix(240))))
    }

    func failRunningServerForLocalNetworkPermission() async {
        await stopRunningServer(status: .localNetworkPermissionDenied)
    }

    private func stopRunningServer(status: RemoteTransportStatus) async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        let activeListener = listener
        listener = nil
        activeListenerID = nil
        activeListener?.cancel()
        let openConnections = connections.values
        connections.removeAll()
        connectionBindings.removeAll()
        for connection in openConnections { await connection.close() }
        components = nil
        setStatus(status)
        emit(.connectionCountChanged(0))
    }

    func failStart(_ message: String) {
        failStart(.listenerFailed(String(message.prefix(240))))
    }

    func failStart(caught error: any Error) {
        guard let networkError = error as? NWError else {
            failStart(error.localizedDescription)
            return
        }
        if NWLocalNetworkPermissionDenial.matches(networkError) {
            failStart(.localNetworkPermissionDenied)
        } else {
            failStart(error.localizedDescription)
        }
    }

    func failStart(_ error: RemoteTransportLifecycleError) {
        let activeListener = listener
        listener = nil
        activeListenerID = nil
        activeListener?.cancel()
        connectionBindings.removeAll()
        startContinuation?.resume(throwing: error)
        startContinuation = nil
        switch error {
        case .localNetworkPermissionDenied:
            setStatus(.localNetworkPermissionDenied)
        case .listenerFailed(let message):
            setStatus(.failed(message: message))
        case .alreadyRunning, .invalidConfiguration:
            setStatus(.failed(message: String(describing: error)))
        }
    }
}
