import Foundation

public struct WebSocketFrameCodec: Sendable {
    private let maximumPayloadBytes: Int

    public init(limits: RemoteTransportLimits = RemoteTransportLimits()) {
        maximumPayloadBytes = limits.maximumWebSocketFrameBytes
    }

    public func parseClientFrame(_ data: Data) throws -> ParsedWebSocketFrame {
        guard data.count >= 2 else { throw RemoteTransportError.incompleteRequest }
        let first = data[data.startIndex]
        let second = data[data.startIndex + 1]
        guard first & 0x70 == 0, first & 0x80 != 0, second & 0x80 != 0,
            let opcode = WebSocketOpcode(rawValue: first & 0x0F)
        else {
            throw RemoteTransportError.invalidWebSocketFrame
        }
        var offset = 2
        let encodedLength = Int(second & 0x7F)
        let payloadLength = try readLength(encodedLength, data: data, offset: &offset)
        guard payloadLength <= maximumPayloadBytes else { throw RemoteTransportError.frameTooLarge }
        if opcode != .text, payloadLength > 125 { throw RemoteTransportError.invalidWebSocketFrame }
        guard data.count >= offset + 4 + payloadLength else {
            throw RemoteTransportError.incompleteRequest
        }
        let mask = Array(data[offset..<(offset + 4)])
        offset += 4
        var payload = Data(capacity: payloadLength)
        for index in 0..<payloadLength {
            payload.append(data[offset + index] ^ mask[index % 4])
        }
        if opcode == .text, String(data: payload, encoding: .utf8) == nil {
            throw RemoteTransportError.invalidWebSocketFrame
        }
        return ParsedWebSocketFrame(
            frame: WebSocketFrame(opcode: opcode, payload: payload),
            consumedBytes: offset + payloadLength
        )
    }

    public func encodeServerFrame(_ frame: WebSocketFrame) throws -> Data {
        guard frame.payload.count <= maximumPayloadBytes else { throw RemoteTransportError.frameTooLarge }
        var result = Data([0x80 | frame.opcode.rawValue])
        let count = frame.payload.count
        if count <= 125 {
            result.append(UInt8(count))
        } else if count <= Int(UInt16.max) {
            result.append(126)
            append(UInt64(count), byteCount: 2, to: &result)
        } else {
            result.append(127)
            append(UInt64(count), byteCount: 8, to: &result)
        }
        result.append(frame.payload)
        return result
    }

    private func readLength(_ marker: Int, data: Data, offset: inout Int) throws -> Int {
        if marker <= 125 { return marker }
        let byteCount = marker == 126 ? 2 : 8
        guard data.count >= offset + byteCount else { throw RemoteTransportError.incompleteRequest }
        var value: UInt64 = 0
        for byte in data[offset..<(offset + byteCount)] { value = (value << 8) | UInt64(byte) }
        offset += byteCount
        guard value <= UInt64(Int.max), value <= UInt64(maximumPayloadBytes) else {
            throw RemoteTransportError.frameTooLarge
        }
        return Int(value)
    }

    private func append(_ value: UInt64, byteCount: Int, to data: inout Data) {
        for shift in stride(from: (byteCount - 1) * 8, through: 0, by: -8) {
            data.append(UInt8((value >> UInt64(shift)) & 0xFF))
        }
    }
}
