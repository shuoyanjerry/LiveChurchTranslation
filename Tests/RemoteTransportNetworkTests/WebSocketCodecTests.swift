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

    @Test("Non-minimal payload length encodings are rejected")
    func nonMinimalLengthEncodings() {
        let codec = WebSocketFrameCodec()
        let marker126 = Data([0x81, 0xFE, 0x00, 0x01])
        let marker127 = Data([0x81, 0xFF, 0, 0, 0, 0, 0, 0, 0xFF, 0xFF])
        let marker127HighBit = Data([0x81, 0xFF, 0x80, 0, 0, 0, 0, 0, 0, 0])

        #expect(throws: RemoteTransportError.invalidWebSocketFrame) {
            try codec.parseClientFrame(marker126)
        }
        #expect(throws: RemoteTransportError.invalidWebSocketFrame) {
            try codec.parseClientFrame(marker127)
        }
        #expect(throws: RemoteTransportError.invalidWebSocketFrame) {
            try codec.parseClientFrame(marker127HighBit)
        }
    }

    @Test("Coalesced frames remain parseable after consuming the first frame")
    func coalescedFrames() throws {
        let codec = WebSocketFrameCodec()
        let firstFrame = maskedTextFrame("Listening", mask: [0x01, 0x02, 0x03, 0x04])
        let secondText = "Translating"
        let secondFrame = maskedTextFrame(secondText, mask: [0xA1, 0xB2, 0xC3, 0xD4])
        var buffer = firstFrame + secondFrame

        let first = try codec.parseClientFrame(buffer)
        #expect(first.frame.text == "Listening")
        buffer.removeFirst(first.consumedBytes)
        #expect(buffer.startIndex == first.consumedBytes)

        let second = try codec.parseClientFrame(buffer)
        #expect(second.frame.text == secondText)
        #expect(second.consumedBytes == secondFrame.count)
    }

    @Test("An extended-length frame parses at a nonzero Data start index")
    func extendedLengthFrameWithNonzeroStartIndex() throws {
        let codec = WebSocketFrameCodec()
        let text = String(repeating: "a", count: 126)
        let frame = maskedTextFrame(text, mask: [0x11, 0x22, 0x33, 0x44])
        var buffer = Data([0xDE, 0xAD]) + frame
        buffer.removeFirst(2)

        #expect(buffer.startIndex == 2)
        let parsed = try codec.parseClientFrame(buffer)
        #expect(parsed.frame.text == text)
        #expect(parsed.consumedBytes == frame.count)
    }

    @Test("Every partial extended-length frame is reported as incomplete")
    func fragmentedExtendedLengthFrame() throws {
        let codec = WebSocketFrameCodec()
        let text = String(repeating: "a", count: 126)
        let frame = maskedTextFrame(text, mask: [0x11, 0x22, 0x33, 0x44])

        for splitIndex in 0..<frame.count {
            let fragment = Data(frame.prefix(splitIndex))
            #expect(throws: RemoteTransportError.incompleteRequest) {
                try codec.parseClientFrame(fragment)
            }
        }

        let parsed = try codec.parseClientFrame(frame)
        #expect(parsed.frame.text == text)
        #expect(parsed.consumedBytes == frame.count)
    }

    @Test("Short extended-length headers are safe at a nonzero Data start index")
    func shortExtendedLengthHeaderWithNonzeroStartIndex() {
        let codec = WebSocketFrameCodec()
        let shortHeaders = [
            Data([0x81, 0xFE]),
            Data([0x81, 0xFE, 0x00]),
            Data([0x81, 0xFF]),
            Data([0x81, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
        ]
        for suffix in shortHeaders {
            var buffer = Data([0xDE, 0xAD]) + suffix
            buffer.removeFirst(2)
            #expect(buffer.startIndex == 2)
            #expect(throws: RemoteTransportError.incompleteRequest) {
                try codec.parseClientFrame(buffer)
            }
        }
    }
}

func maskedTextFrame(_ text: String, mask: [UInt8]) -> Data {
    maskedFrame(opcode: .text, payload: Data(text.utf8), mask: mask)
}

func maskedFrame(
    opcode: WebSocketOpcode,
    payload: Data,
    mask: [UInt8] = [0x11, 0x22, 0x33, 0x44]
) -> Data {
    var frame = Data([0x80 | opcode.rawValue])
    if payload.count <= 125 {
        frame.append(0x80 | UInt8(payload.count))
    } else if payload.count <= Int(UInt16.max) {
        frame.append(0x80 | 126)
        frame.append(UInt8((payload.count >> 8) & 0xFF))
        frame.append(UInt8(payload.count & 0xFF))
    } else {
        frame.append(0x80 | 127)
        for shift in stride(from: 56, through: 0, by: -8) {
            frame.append(UInt8((UInt64(payload.count) >> UInt64(shift)) & 0xFF))
        }
    }
    frame.append(contentsOf: mask)
    for (index, byte) in payload.enumerated() {
        frame.append(byte ^ mask[index % mask.count])
    }
    return frame
}
