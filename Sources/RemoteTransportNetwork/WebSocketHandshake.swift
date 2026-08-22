import CryptoKit
import Foundation

public struct WebSocketHandshake: Sendable {
    public init() {}

    public func response(for request: RemoteHTTPRequest) throws -> RemoteHTTPResponse {
        guard request.method == "GET",
            containsToken(request.singleHeader("connection"), token: "upgrade"),
            request.singleHeader("upgrade")?.lowercased() == "websocket",
            request.singleHeader("sec-websocket-version") == "13",
            request.singleHeader("sec-websocket-protocol") == nil,
            let key = request.singleHeader("sec-websocket-key"),
            Data(base64Encoded: key)?.count == 16
        else {
            throw RemoteTransportError.invalidWebSocketHandshake
        }
        let magic = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let digest = Insecure.SHA1.hash(data: Data(magic.utf8))
        let accept = Data(digest).base64EncodedString()
        return RemoteHTTPResponse(
            status: 101,
            reason: "Switching Protocols",
            headers: [
                "Connection": "Upgrade",
                "Upgrade": "websocket",
                "Sec-WebSocket-Accept": accept,
            ]
        )
    }

    private func containsToken(_ value: String?, token: String) -> Bool {
        value?.split(separator: ",").contains {
            $0.trimmingCharacters(in: .whitespaces).lowercased() == token
        } ?? false
    }
}
