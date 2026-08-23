import LoggingAPI
import OSLog

public struct UnifiedLogger: AppLogger {
    private let subsystem: String

    public init(subsystem: String) {
        self.subsystem = subsystem
    }

    public func write(_ record: LogRecord) {
        let logger = Logger(subsystem: subsystem, category: record.category)
        let payload = UnifiedLogPayload(record).text
        logger.log(level: record.level.osLogType, "\(payload, privacy: .private)")
    }
}

struct UnifiedLogPayload: Equatable, Sendable {
    let text: String

    init(_ record: LogRecord) {
        let metadata = record.metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        text = metadata.isEmpty ? record.message : "\(record.message) [\(metadata)]"
    }
}

extension LogLevel {
    fileprivate var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .notice: .default
        case .error: .error
        case .fault: .fault
        }
    }
}
