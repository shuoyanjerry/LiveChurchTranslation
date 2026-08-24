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
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: exportDirectory.path
        )
        let url = exportDirectory.appending(
            path: "diagnostics-\(UUID().uuidString.lowercased()).json"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(records).write(to: url, options: .atomic)
            try fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: url.path
            )
        } catch {
            try? fileManager.removeItem(at: url)
            throw error
        }
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
