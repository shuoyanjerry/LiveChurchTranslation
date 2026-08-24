import AudioImportAPI
import SessionManagementAPI

@MainActor
public final class ApplicationShutdownCoordinator {
    private let shutdownImport: @Sendable () async -> Void
    private let prepareSessionForShutdown: @Sendable () async -> Void
    private let shutdownModelPreparations: @Sendable () async -> Void
    private let shutdownSession: @Sendable () async -> Void
    private var completions: [@MainActor () -> Void] = []
    private var isPending = false

    public init(
        controller: any LiveSessionController,
        audioImporter: any AudioImporting,
        modelPreparations: [any ModelPreparationController]
    ) {
        shutdownImport = { await audioImporter.shutdown() }
        prepareSessionForShutdown = { await controller.prepareForShutdown() }
        shutdownModelPreparations = {
            for modelPreparation in modelPreparations {
                await modelPreparation.shutdownModelPreparation()
            }
        }
        shutdownSession = { await controller.shutdown() }
    }

    init(
        shutdownImport: @escaping @Sendable () async -> Void,
        prepareSessionForShutdown: @escaping @Sendable () async -> Void,
        shutdownModelPreparations: @escaping @Sendable () async -> Void,
        shutdownSession: @escaping @Sendable () async -> Void
    ) {
        self.shutdownImport = shutdownImport
        self.prepareSessionForShutdown = prepareSessionForShutdown
        self.shutdownModelPreparations = shutdownModelPreparations
        self.shutdownSession = shutdownSession
    }

    public func request(completion: @escaping @MainActor () -> Void) {
        completions.append(completion)
        guard !isPending else { return }
        isPending = true
        Task {
            await shutdownImport()
            await prepareSessionForShutdown()
            await shutdownModelPreparations()
            await shutdownSession()
            let pendingCompletions = completions
            completions.removeAll()
            isPending = false
            for pendingCompletion in pendingCompletions {
                pendingCompletion()
            }
        }
    }

    public func handleTerminationSignal(onCleanExit: @escaping @MainActor () -> Void) {
        request(completion: onCleanExit)
    }
}
