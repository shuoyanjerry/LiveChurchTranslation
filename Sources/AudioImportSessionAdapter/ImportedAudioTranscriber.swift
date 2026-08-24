import AudioCaptureAPI
import AudioImportAPI
import Foundation
import SessionManagementAPI
import SettingsAPI

@MainActor
public final class ImportedAudioTranscriber: AudioImporting {
    public typealias ControllerFactory =
        (URL, TranslationMode, String?) throws -> any LiveSessionController

    private let inputDeviceID: AudioInputID
    private let makeController: ControllerFactory
    private var activeController: (any LiveSessionController)?
    private var activeImportTask: Task<Void, any Error>?
    private var cancellationRequested = false

    public init(
        inputDeviceID: AudioInputID,
        makeController: @escaping ControllerFactory
    ) {
        self.inputDeviceID = inputDeviceID
        self.makeController = makeController
    }

    public func importAudio(
        from url: URL,
        mode: TranslationMode,
        sessionTitle: String?
    ) async throws {
        guard activeController == nil else {
            throw AudioImportError.transcriptionFailed("另一个音频文件正在处理中。")
        }
        cancellationRequested = false
        let controller = try makeController(url, mode, sessionTitle)
        activeController = controller
        defer {
            activeController = nil
            activeImportTask = nil
            cancellationRequested = false
        }

        let task = Task { [self, controller] in
            try Task.checkCancellation()
            let events = await controller.events()
            try Task.checkCancellation()
            await controller.start(inputDeviceID: inputDeviceID)
            try Task.checkCancellation()
            try await waitForCompletion(events)
        }
        activeImportTask = task
        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
                Task { await controller.stop() }
            }
        } catch is CancellationError {
            await controller.stop()
            throw AudioImportError.cancelled
        } catch {
            await controller.stop()
            if cancellationRequested { throw AudioImportError.cancelled }
            throw error
        }
    }

    public func cancelImport() async {
        cancellationRequested = true
        activeImportTask?.cancel()
        await activeController?.stop()
    }

    private func waitForCompletion(
        _ events: AsyncStream<LiveSessionEvent>
    ) async throws {
        var observedSessionID: UUID?
        for await event in events {
            try Task.checkCancellation()
            guard case .stateChanged(let snapshot) = event else { continue }
            if let sessionID = snapshot.sessionID {
                guard observedSessionID == nil || observedSessionID == sessionID else {
                    throw AudioImportError.transcriptionFailed("处理流程意外切换了项目。")
                }
                observedSessionID = sessionID
                continue
            }
            guard let observedSessionID else { continue }
            try AudioImportCompletionValidator.validate(
                snapshot,
                savedSessionID: observedSessionID
            )
            return
        }
        try Task.checkCancellation()
        throw AudioImportError.transcriptionFailed("处理流程意外结束。")
    }
}
