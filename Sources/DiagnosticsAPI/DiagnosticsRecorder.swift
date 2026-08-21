import Foundation

public enum DiagnosticSeverity: String, Codable, Sendable {
    case info
    case warning
    case error
}

public struct DiagnosticEvent: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let severity: DiagnosticSeverity
    public let component: String
    public let message: String
    public let measurements: [String: Double]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        severity: DiagnosticSeverity,
        component: String,
        message: String,
        measurements: [String: Double] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.severity = severity
        self.component = component
        self.message = message
        self.measurements = measurements
    }
}

public protocol DiagnosticsRecorder: Sendable {
    func record(_ event: DiagnosticEvent) async
    func recent(limit: Int) async -> [DiagnosticEvent]
    func export() async throws -> URL
}
