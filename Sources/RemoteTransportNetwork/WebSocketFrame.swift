import Foundation

public enum WebSocketOpcode: UInt8, Equatable, Sendable {
    case text = 0x1
    case close = 0x8
    case ping = 0x9
    case pong = 0xA
}

public struct WebSocketFrame: Equatable, Sendable {
    public let opcode: WebSocketOpcode
    public let payload: Data

    public init(opcode: WebSocketOpcode, payload: Data) {
        self.opcode = opcode
        self.payload = payload
    }

    public var text: String? {
        opcode == .text ? String(data: payload, encoding: .utf8) : nil
    }
}

public struct ParsedWebSocketFrame: Equatable, Sendable {
    public let frame: WebSocketFrame
    public let consumedBytes: Int

    public init(frame: WebSocketFrame, consumedBytes: Int) {
        self.frame = frame
        self.consumedBytes = consumedBytes
    }
}
