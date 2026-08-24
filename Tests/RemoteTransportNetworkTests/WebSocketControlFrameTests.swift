import Foundation
import RemoteTransportNetwork
import Testing

@Suite("WebSocket extended and control frames")
struct WebSocketControlFrameTests {
    @Test("The 64-bit length form accepts its smallest legal payload")
    func legal64BitLength() throws {
        let codec = WebSocketFrameCodec()
        let text = String(repeating: "a", count: 65_536)
        let frame = maskedTextFrame(text, mask: [0x31, 0x42, 0x53, 0x64])

        let parsed = try codec.parseClientFrame(frame)

        #expect(parsed.frame.text == text)
        #expect(parsed.consumedBytes == frame.count)
    }

    @Test("Close payloads require a legal code and UTF-8 reason")
    func closePayloadValidation() throws {
        let codec = WebSocketFrameCodec()
        let validPayload = Data([0x03, 0xE8]) + Data("Done".utf8)
        let valid = maskedFrame(opcode: .close, payload: validPayload)
        #expect(try codec.parseClientFrame(valid).frame.payload == validPayload)

        let malformedPayloads = [
            Data([0x03]),
            Data([0x03, 0xED]),
            Data([0x03, 0xE8, 0xFF]),
        ]
        for payload in malformedPayloads {
            #expect(throws: RemoteTransportError.invalidWebSocketFrame) {
                try codec.parseClientFrame(maskedFrame(opcode: .close, payload: payload))
            }
        }
    }
}
