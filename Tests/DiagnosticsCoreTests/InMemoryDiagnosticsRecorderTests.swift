import DiagnosticsAPI
import DiagnosticsCore
import Foundation
import LoggingAPI
import Testing

@Suite("Diagnostics export privacy")
struct InMemoryDiagnosticsRecorderTests {
    @Test("Exports are private and never overwrite an earlier bundle")
    func privateUniqueExports() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(
            path: "diagnostics-tests-\(UUID().uuidString.lowercased())",
            directoryHint: .isDirectory
        )
        defer { try? fileManager.removeItem(at: root) }
        let recorder = InMemoryDiagnosticsRecorder(logger: SilentLogger(), exportDirectory: root)
        await recorder.record(
            .init(severity: .warning, component: "transport", message: "redacted-event")
        )

        let first = try await recorder.export()
        let second = try await recorder.export()

        #expect(first != second)
        #expect(try permissions(of: root) == 0o700)
        #expect(try permissions(of: first) == 0o600)
        #expect(try permissions(of: second) == 0o600)
        #expect(try String(contentsOf: first, encoding: .utf8).contains("redacted-event"))
    }

    private func permissions(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try #require(attributes[.posixPermissions] as? Int) & 0o777
    }
}

private struct SilentLogger: AppLogger {
    func write(_ record: LogRecord) {}
}
