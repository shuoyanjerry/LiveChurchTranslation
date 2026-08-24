import Foundation

/// Reports bytes written for the current artifact.
public typealias ModelHTTPProgress =
    @Sendable (
        _ receivedBytes: Int64,
        _ expectedBytes: Int64?
    ) -> Void

/// HTTP metadata required for post-download validation.
public struct ModelHTTPTransferResult: Equatable, Sendable {
    public let statusCode: Int
    public let contentLength: Int64?

    public init(statusCode: Int, contentLength: Int64?) {
        self.statusCode = statusCode
        self.contentLength = contentLength
    }
}

/// Injectable boundary that downloads one remote artifact to a `.part` URL.
public protocol ModelHTTPTransport: Sendable {
    func download(
        from remoteURL: URL,
        to localURL: URL,
        maximumBytes: Int64,
        progress: @escaping ModelHTTPProgress
    ) async throws -> ModelHTTPTransferResult
}

/// Failures emitted by the production HTTP transport.
public enum ModelHTTPTransportError: LocalizedError, Equatable, Sendable {
    case nonHTTPResponse
    case rejectedStatus(Int)
    case destinationExists
    case responseTooLarge(maximumBytes: Int64)
    case rejectedRedirect

    public var errorDescription: String? {
        switch self {
        case .nonHTTPResponse: "The model server returned a non-HTTP response."
        case .rejectedStatus(let status): "The model server returned HTTP \(status)."
        case .destinationExists: "The download destination already exists."
        case .responseTooLarge(let maximumBytes):
            "The model response exceeded its \(maximumBytes)-byte limit."
        case .rejectedRedirect: "The model server redirected to an unsafe location."
        }
    }
}
