import Foundation
import RemoteTransportNetwork
import Testing

@Suite("WebSocket protocol boundary")
struct WebSocketCodecTests {
    @Test("The RFC handshake vector is accepted")
    func handshake() throws {
        let request = RemoteHTTPRequest(
            method: "GET",
            target: "/ws",
            path: "/ws",
            query: nil,
            headers: [
                "connection": ["Upgrade"],
                "upgrade": ["websocket"],
                "sec-websocket-version": ["13"],
                "sec-websocket-key": ["dGhlIHNhbXBsZSBub25jZQ=="],
            ],
            body: Data()
        )
        let response = try WebSocketHandshake().response(for: request)
        #expect(response.headers["Sec-WebSocket-Accept"] == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    }

    @Test("Unmasked and oversized client frames fail before allocation")
    func malformedFrames() {
        let codec = WebSocketFrameCodec(limits: .init(maximumWebSocketFrameBytes: 1_024))
        #expect(throws: RemoteTransportError.invalidWebSocketFrame) {
            try codec.parseClientFrame(Data([0x81, 0x01, 0x41]))
        }
        let oversized = Data([0x81, 0xFE, 0x04, 0x01])
        #expect(throws: RemoteTransportError.frameTooLarge) {
            try codec.parseClientFrame(oversized)
        }
    }
}
