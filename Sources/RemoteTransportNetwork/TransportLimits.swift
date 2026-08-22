public struct RemoteTransportLimits: Equatable, Sendable {
    public let maximumRequestLineBytes: Int
    public let maximumHeaderBytes: Int
    public let maximumHeaderCount: Int
    public let maximumBodyBytes: Int
    public let maximumWebSocketFrameBytes: Int

    public init(
        maximumRequestLineBytes: Int = 2_048,
        maximumHeaderBytes: Int = 16_384,
        maximumHeaderCount: Int = 64,
        maximumBodyBytes: Int = 65_536,
        maximumWebSocketFrameBytes: Int = 4_194_304
    ) {
        self.maximumRequestLineBytes = min(max(maximumRequestLineBytes, 256), 8_192)
        self.maximumHeaderBytes = min(max(maximumHeaderBytes, 2_048), 65_536)
        self.maximumHeaderCount = min(max(maximumHeaderCount, 8), 128)
        self.maximumBodyBytes = min(max(maximumBodyBytes, 1_024), 1_048_576)
        self.maximumWebSocketFrameBytes = min(max(maximumWebSocketFrameBytes, 1_024), 8_388_608)
    }
}

public enum RemoteTransportError: String, Error, Equatable, Sendable {
    case incompleteRequest
    case requestLineTooLarge
    case headersTooLarge
    case tooManyHeaders
    case malformedRequest
    case malformedHeader
    case duplicateSecurityHeader
    case bodyTooLarge
    case unsupportedTransferEncoding
    case nonLocalPeer
    case invalidHost
    case invalidOrigin
    case credentialsInURL
    case unauthorized
    case invalidWebSocketHandshake
    case frameTooLarge
    case invalidWebSocketFrame
}
