import DiagnosticsAPI
import Foundation
import LoggingAPI
import TranscriptAPI

enum SessionPersistenceResult: Sendable {
    case noTranscript
    case saved
    case failed(transcript: TranscriptSession, message: String)
}

struct SessionFinalizer: Sendable {
    let dependencies: LiveSessionDependencies

    func finish(sessionID: UUID) async -> SessionPersistenceResult {
        let result = await persistFinishedTranscript()
        dependencies.logger.write(
            LogRecord(
                level: result.completedCleanly ? .notice : .error,
                category: "Session",
                message: result.logMessage,
                metadata: ["id": sessionID.uuidString]
            )
        )
        return result
    }

    func fail(_ message: String) async -> SessionPersistenceResult {
        await dependencies.diagnostics.record(
            DiagnosticEvent(severity: .error, component: "Session", message: message)
        )
        return await persistFinishedTranscript()
    }

    func logRecoverable(_ error: Error) {
        dependencies.logger.write(
            LogRecord(level: .error, category: "Pipeline", message: error.localizedDescription)
        )
    }

    private func persistFinishedTranscript() async -> SessionPersistenceResult {
        guard let transcript = await dependencies.transcript.finish(at: Date()) else {
            return .noTranscript
        }
        do {
            try await dependencies.transcriptStore.finish(transcript)
            return .saved
        } catch {
            let message = error.localizedDescription
            await dependencies.diagnostics.record(
                DiagnosticEvent(
                    severity: .error,
                    component: "Persistence",
                    message: message
                )
            )
            return .failed(transcript: transcript, message: message)
        }
    }
}

extension SessionPersistenceResult {
    fileprivate var completedCleanly: Bool {
        if case .failed = self { return false }
        return true
    }

    fileprivate var logMessage: String {
        switch self {
        case .noTranscript: "Session closed without a transcript"
        case .saved: "Session saved"
        case .failed: "Session finalization incomplete"
        }
    }
}
