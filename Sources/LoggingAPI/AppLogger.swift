import Foundation

public enum LogLevel: String, Codable, Sendable {
    case debug
    case info
    case notice
    case error
    case fault
}

public struct LogRecord: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let message: String
    public let metadata: [String: String]

    public init(
        timestamp: Date = Date(),
        level: LogLevel,
        category: String,
        message: String,
        metadata: [String: String] = [:]
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
    }
}

public protocol AppLogger: Sendable {
    func write(_ record: LogRecord)
}
