import AudioCaptureAPI
import AudioImportAPI
import Foundation
import SessionManagementAPI
import SettingsAPI

@MainActor
public final class ImportedAudioTranscriber: AudioImporting {
    public typealias ControllerFactory =
        (URL, TranslationMode, String?) throws -> any LiveSessionController
    public typealias SourceValidator = @Sendable (URL) async throws -> Void

    private let inputDeviceID: AudioInputID
    private let validateSource: SourceValidator
    private let makeController: ControllerFactory
    private var activeController: (any LiveSessionController)?
    private var activeValidationTask: Task<Void, any Error>?
    private var activeImportTask: Task<Void, any Error>?
    private var importInProgress = false
    private var cancellationRequested = false
    private var isShuttingDown = false

    public init(
        inputDeviceID: AudioInputID,
        validateSource: @escaping SourceValidator = { _ in },
        makeController: @escaping ControllerFactory
    ) {
        self.inputDeviceID = inputDeviceID
        self.validateSource = validateSource
        self.makeController = makeController
    }

    public func importAudio(
        from url: URL,
        mode: TranslationMode,
        sessionTitle: String?
    ) async throws {
        try beginImport()
        defer { finishImport() }
        do {
            try await validate(url)
            try await transcribe(url: url, mode: mode, sessionTitle: sessionTitle)
        } catch is CancellationError {
            throw AudioImportError.cancelled
        }
    }

    public func cancelImport() async {
        cancellationRequested = true
        activeValidationTask?.cancel()
        activeImportTask?.cancel()
        await activeController?.stop()
    }

    public func shutdown() async {
        isShuttingDown = true
        cancellationRequested = true
        let validationTask = activeValidationTask
        let importTask = activeImportTask
        validationTask?.cancel()
        importTask?.cancel()
        await activeController?.prepareForShutdown()
        _ = await validationTask?.result
        _ = await importTask?.result
    }
}

extension ImportedAudioTranscriber {
    fileprivate func beginImport() throws {
        guard !isShuttingDown else { throw AudioImportError.cancelled }
        guard !importInProgress else {
            throw AudioImportError.transcriptionFailed("另一个媒体文件正在处理中。")
        }
        importInProgress = true
        cancellationRequested = false
    }

    fileprivate func finishImport() {
        activeController = nil
        activeValidationTask = nil
        activeImportTask = nil
        importInProgress = false
        cancellationRequested = false
    }

    fileprivate func validate(_ url: URL) async throws {
        let task = Task { [validateSource] in
            try Task.checkCancellation()
            try await validateSource(url)
            try Task.checkCancellation()
        }
        activeValidationTask = task
        defer { activeValidationTask = nil }
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    fileprivate func transcribe(
        url: URL,
        mode: TranslationMode,
        sessionTitle: String?
    ) async throws {
        guard !cancellationRequested else { throw AudioImportError.cancelled }
        let controller = try makeController(url, mode, sessionTitle)
        activeController = controller
        let task = makeImportTask(controller: controller)
        activeImportTask = task
        do {
            try await awaitCompletion(of: task, controller: controller)
        } catch is CancellationError {
            await controller.stop()
            throw AudioImportError.cancelled
        } catch {
            await controller.stop()
            if cancellationRequested { throw AudioImportError.cancelled }
            throw error
        }
    }

    fileprivate func makeImportTask(
        controller: any LiveSessionController
    ) -> Task<Void, any Error> {
        Task { [self, controller] in
            try Task.checkCancellation()
            let events = await controller.events()
            try Task.checkCancellation()
            await controller.start(inputDeviceID: inputDeviceID)
            try Task.checkCancellation()
            try await waitForCompletion(events)
        }
    }

    fileprivate func awaitCompletion(
        of task: Task<Void, any Error>,
        controller: any LiveSessionController
    ) async throws {
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
            Task { await controller.stop() }
        }
    }

    fileprivate func waitForCompletion(
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
