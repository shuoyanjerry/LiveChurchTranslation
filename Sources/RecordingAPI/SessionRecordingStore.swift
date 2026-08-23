import AudioCaptureAPI
import Foundation

public protocol SessionRecordingStore: Sendable {
    func begin(sessionID: UUID) async throws
    func append(_ frame: AudioFrame, to sessionID: UUID) async throws
    func discard(sessionID: UUID) async throws

    @discardableResult
    func finish(sessionID: UUID) async throws -> SessionRecordingMetadata

    @discardableResult
    func repairInterruptedRecording(
        sessionID: UUID
    ) async throws -> SessionRecordingMetadata?
}
