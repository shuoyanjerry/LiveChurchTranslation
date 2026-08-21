import DiagnosticsAPI
import Foundation
import LoggingAPI

public actor InMemoryDiagnosticsRecorder: DiagnosticsRecorder {
    private let logger: any AppLogger
    private let exportDirectory: URL
    private let capacity: Int
    private var records: [DiagnosticEvent] = []

    public init(logger: any AppLogger, exportDirectory: URL, capacity: Int = 500) {
        self.logger = logger
        self.exportDirectory = exportDirectory
        self.capacity = max(1, capacity)
    }

    public func record(_ event: DiagnosticEvent) async {
        records.append(event)
        if records.count > capacity {
            records.removeFirst(records.count - capacity)
        }
        logger.write(
            LogRecord(
                level: logLevel(for: event.severity),
                category: event.component,
                message: event.message
            )
        )
    }

    public func recent(limit: Int) async -> [DiagnosticEvent] {
        Array(records.suffix(max(0, limit)))
    }

    public func export() async throws -> URL {
        try FileManager.default.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true
        )
        let url = exportDirectory.appending(
            path: "diagnostics-\(Int(Date().timeIntervalSince1970)).json"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: url, options: .atomic)
        return url
    }

    private func logLevel(for severity: DiagnosticSeverity) -> LogLevel {
        switch severity {
        case .info: .info
        case .warning: .notice
        case .error: .error
        }
    }
}
