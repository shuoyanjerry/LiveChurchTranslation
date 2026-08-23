import Foundation
import RemoteDiscoveryAPI

public struct RemoteTransportConfiguration: Equatable, Sendable {
    public let advertisedHostName: String
    public let preferredPort: UInt16
    public let maximumConnections: Int
    public let bonjour: RemoteBonjourDescriptor

    public init(
        advertisedHostName: String,
        preferredPort: UInt16 = 0,
        maximumConnections: Int = 32,
        bonjour: RemoteBonjourDescriptor
    ) {
        self.advertisedHostName = advertisedHostName.lowercased()
        self.preferredPort = preferredPort
        self.maximumConnections = min(max(maximumConnections, 1), 128)
        self.bonjour = bonjour
    }
}

public struct RemoteEndpoint: Equatable, Codable, Sendable {
    public let baseURL: URL
    public let port: UInt16

    public init(baseURL: URL, port: UInt16) {
        self.baseURL = baseURL
        self.port = port
    }
}

public enum RemoteTransportStatus: Equatable, Sendable {
    case stopped
    case starting
    case running(RemoteEndpoint)
    case localNetworkPermissionDenied
    case failed(message: String)
}

public enum RemoteTransportEvent: Equatable, Sendable {
    case statusChanged(RemoteTransportStatus)
    case connectionCountChanged(Int)
}

public enum RemoteTransportLifecycleError: Error, Equatable, Sendable {
    case alreadyRunning
    case invalidConfiguration
    case localNetworkPermissionDenied
    case listenerFailed(String)
}
