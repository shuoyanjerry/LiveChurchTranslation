import Foundation

public struct WebSocketFrameCodec: Sendable {
    private let maximumPayloadBytes: Int

    public init(limits: RemoteTransportLimits = RemoteTransportLimits()) {
        maximumPayloadBytes = limits.maximumWebSocketFrameBytes
    }

    public func parseClientFrame(_ data: Data) throws -> ParsedWebSocketFrame {
        var reader = WebSocketFrameReader(data: data)
        let first = try reader.readByte()
        let second = try reader.readByte()
        guard first & 0x70 == 0, first & 0x80 != 0, second & 0x80 != 0,
            let opcode = WebSocketOpcode(rawValue: first & 0x0F)
        else {
            throw RemoteTransportError.invalidWebSocketFrame
        }
        let encodedLength = Int(second & 0x7F)
        let payloadLength = try readLength(encodedLength, reader: &reader)
        guard payloadLength <= maximumPayloadBytes else { throw RemoteTransportError.frameTooLarge }
        if opcode != .text, payloadLength > 125 { throw RemoteTransportError.invalidWebSocketFrame }
        let mask = Array(try reader.readBytes(count: 4))
        let maskedPayload = try reader.readBytes(count: payloadLength)
        var payload = Data(capacity: payloadLength)
        for (index, byte) in maskedPayload.enumerated() {
            payload.append(byte ^ mask[index % 4])
        }
        if opcode == .text, String(data: payload, encoding: .utf8) == nil {
            throw RemoteTransportError.invalidWebSocketFrame
        }
        if opcode == .close { try validateClosePayload(payload) }
        return ParsedWebSocketFrame(
            frame: WebSocketFrame(opcode: opcode, payload: payload),
            consumedBytes: reader.consumedBytes
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

    private func readLength(
        _ marker: Int,
        reader: inout WebSocketFrameReader
    ) throws -> Int {
        if marker <= 125 { return marker }
        let byteCount = marker == 126 ? 2 : 8
        var value: UInt64 = 0
        for _ in 0..<byteCount {
            value = (value << 8) | UInt64(try reader.readByte())
        }
        if marker == 126, value < 126 { throw RemoteTransportError.invalidWebSocketFrame }
        if marker == 127, value & (UInt64(1) << 63) != 0 {
            throw RemoteTransportError.invalidWebSocketFrame
        }
        if marker == 127, value <= UInt64(UInt16.max) {
            throw RemoteTransportError.invalidWebSocketFrame
        }
        guard value <= UInt64(Int.max), value <= UInt64(maximumPayloadBytes) else {
            throw RemoteTransportError.frameTooLarge
        }
        return Int(value)
    }

    private func validateClosePayload(_ payload: Data) throws {
        guard payload.count != 1 else { throw RemoteTransportError.invalidWebSocketFrame }
        guard payload.count >= 2 else { return }
        let code =
            (UInt16(payload[payload.startIndex]) << 8)
            | UInt16(payload[payload.index(after: payload.startIndex)])
        let isProtocolCode = (1_000...1_014).contains(code) && ![1_004, 1_005, 1_006].contains(code)
        guard isProtocolCode || (3_000...4_999).contains(code) else {
            throw RemoteTransportError.invalidWebSocketFrame
        }
        let reason = payload.dropFirst(2)
        guard String(data: reason, encoding: .utf8) != nil else {
            throw RemoteTransportError.invalidWebSocketFrame
        }
    }

    private func append(_ value: UInt64, byteCount: Int, to data: inout Data) {
        for shift in stride(from: (byteCount - 1) * 8, through: 0, by: -8) {
            data.append(UInt8((value >> UInt64(shift)) & 0xFF))
        }
    }
}

private struct WebSocketFrameReader {
    private let data: Data
    private var offset = 0

    init(data: Data) {
        self.data = data
    }

    var consumedBytes: Int { offset }

    mutating func readByte() throws -> UInt8 {
        guard offset < data.count else { throw RemoteTransportError.incompleteRequest }
        let index = data.index(data.startIndex, offsetBy: offset)
        offset += 1
        return data[index]
    }

    mutating func readBytes(count: Int) throws -> Data {
        guard count >= 0, count <= data.count - offset else {
            throw RemoteTransportError.incompleteRequest
        }
        let lowerBound = data.index(data.startIndex, offsetBy: offset)
        let upperBound = data.index(lowerBound, offsetBy: count)
        offset += count
        return data[lowerBound..<upperBound]
    }
}
