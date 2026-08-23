import AudioFileAVFoundation
import Foundation
import LiveReader
import SessionManagement
import SessionManagementAPI

@MainActor
final class ImportedAudioTranscriber: AudioImporting {
    typealias ControllerFactory = (URL) throws -> LiveSessionCoordinator

    private let makeController: ControllerFactory
    private var activeController: LiveSessionCoordinator?

    init(makeController: @escaping ControllerFactory) {
        self.makeController = makeController
    }

    func importAudio(from url: URL) async throws {
        guard activeController == nil else {
            throw AudioImportError.transcriptionFailed("另一个音频文件正在处理中。")
        }
        let controller = try makeController(url)
        activeController = controller
        defer { activeController = nil }

        let events = await controller.events()
        await controller.start(inputDeviceID: FileAudioCaptureProvider.inputID)
        do {
            try await waitForCompletion(events)
        } catch {
            await controller.stop()
            throw error
        }
    }

    func cancelImport() async {
        await activeController?.stop()
    }

    private func waitForCompletion(
        _ events: AsyncStream<LiveSessionEvent>
    ) async throws {
        var observedSession = false
        for await event in events {
            try Task.checkCancellation()
            guard case .stateChanged(let snapshot) = event else { continue }
            observedSession = observedSession || snapshot.sessionID != nil
            guard observedSession, snapshot.sessionID == nil else { continue }
            try AudioImportCompletionValidator.validate(snapshot)
            return
        }
        throw AudioImportError.transcriptionFailed("处理流程意外结束。")
    }
}
