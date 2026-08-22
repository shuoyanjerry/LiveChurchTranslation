import Foundation

/// Hardened protocol components to be owned by a byte-stream listener adapter.
public struct RemoteServerComponents: Sendable {
    public let parser: HTTPRequestParser
    public let frameCodec: WebSocketFrameCodec
    public let httpRouter: RemoteHTTPRouter
    public let webSocketGateway: RemoteWebSocketGateway

    public init(
        parser: HTTPRequestParser,
        frameCodec: WebSocketFrameCodec,
        httpRouter: RemoteHTTPRouter,
        webSocketGateway: RemoteWebSocketGateway
    ) {
        self.parser = parser
        self.frameCodec = frameCodec
        self.httpRouter = httpRouter
        self.webSocketGateway = webSocketGateway
    }

    public func handleHTTPBytes(_ bytes: Data, peer: RemotePeerAddress) async throws -> Data {
        let request = try parser.parse(bytes)
        let response = await httpRouter.handle(request, peer: peer)
        return try HTTPResponseSerializer.serialize(response)
    }
}
