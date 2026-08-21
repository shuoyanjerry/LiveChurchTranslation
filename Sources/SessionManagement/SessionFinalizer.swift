import DiagnosticsAPI
import Foundation
import LoggingAPI

struct SessionFinalizer: Sendable {
    let dependencies: LiveSessionDependencies

    func finish(sessionID: UUID) async {
        await persistFinishedTranscript()
        dependencies.logger.write(
            LogRecord(
                level: .notice,
                category: "Session",
                message: "Session saved",
                metadata: ["id": sessionID.uuidString]
            )
        )
    }

    func fail(_ message: String) async {
        await dependencies.capture.stopCapture()
        await dependencies.diagnostics.record(
            DiagnosticEvent(severity: .error, component: "Session", message: message)
        )
        await persistFinishedTranscript()
    }

    func logRecoverable(_ error: Error) {
        dependencies.logger.write(
            LogRecord(level: .error, category: "Pipeline", message: error.localizedDescription)
        )
    }

    private func persistFinishedTranscript() async {
        guard let transcript = await dependencies.transcript.finish(at: Date()) else { return }
        do {
            try await dependencies.transcriptStore.finish(transcript)
        } catch {
            await dependencies.diagnostics.record(
                DiagnosticEvent(
                    severity: .error,
                    component: "Persistence",
                    message: error.localizedDescription
                )
            )
        }
    }
}
