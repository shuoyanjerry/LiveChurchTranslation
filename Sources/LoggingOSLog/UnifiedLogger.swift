import LoggingAPI
import OSLog

public struct UnifiedLogger: AppLogger {
    private let subsystem: String

    public init(subsystem: String) {
        self.subsystem = subsystem
    }

    public func write(_ record: LogRecord) {
        let logger = Logger(subsystem: subsystem, category: record.category)
        let metadata = record.metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let message = metadata.isEmpty ? record.message : "\(record.message) [\(metadata)]"
        switch record.level {
        case .debug: logger.debug("\(message, privacy: .public)")
        case .info: logger.info("\(message, privacy: .public)")
        case .notice: logger.notice("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        case .fault: logger.fault("\(message, privacy: .public)")
        }
    }
}
