import Foundation
import RemoteControlAPI
import RemoteSharingAPI

public actor RevisionCheckedRemoteCommandHandler: RemoteSessionCommandHandling {
    private let revisionReader: any RemoteRevisionReading
    private let sharing: any RemoteSharingControlling
    private let target: any RemoteSessionMutationTarget
    private var minimumRevision: UInt64 = 0
    private var recentResults: [RemoteControlResult] = []
    private var inFlight: [UUID: Task<RemoteControlResult, Never>] = [:]
    private let maximumRecentResults = 256

    public init(
        revisionReader: any RemoteRevisionReading,
        sharing: any RemoteSharingControlling,
        target: any RemoteSessionMutationTarget
    ) {
        self.revisionReader = revisionReader
        self.sharing = sharing
        self.target = target
    }

    public func handle(
        _ request: RemoteControlRequest,
        authorization: RemoteControlAuthorization
    ) async -> RemoteControlResult {
        if let previous = recentResult(request.requestID) { return previous }
        if let existing = inFlight[request.requestID] { return await existing.value }
        guard RemoteControlPolicy.permitsMutation(authorization) else {
            let revision = max(await revisionReader.currentRemoteRevision(), minimumRevision)
            return remember(rejection(request, .viewerIsReadOnly, revision: revision))
        }
        let context = await loadContext()
        if let previous = recentResult(request.requestID) { return previous }
        if let existing = inFlight[request.requestID] { return await existing.value }
        if let reason = preflightRejection(request, context: context) {
            return remember(rejection(request, reason, revision: context.revision))
        }
        return await reserveAndExecute(request, revision: context.revision)
    }

    private func reserveAndExecute(
        _ request: RemoteControlRequest,
        revision: UInt64
    ) async -> RemoteControlResult {
        minimumRevision = revision &+ 1
        let task = executionTask(request, reservedRevision: minimumRevision)
        inFlight[request.requestID] = task
        let result = await task.value
        inFlight.removeValue(forKey: request.requestID)
        return remember(result)
    }

    private func executionTask(
        _ request: RemoteControlRequest,
        reservedRevision: UInt64
    ) -> Task<RemoteControlResult, Never> {
        let task = Task { [target] in
            do {
                switch request.command {
                case .start: try await target.startRemoteSession()
                case .stop: try await target.stopRemoteSession()
                }
                return RemoteControlResult(
                    requestID: request.requestID,
                    accepted: true,
                    authoritativeRevision: reservedRevision
                )
            } catch {
                return RemoteControlResult(
                    requestID: request.requestID,
                    accepted: false,
                    authoritativeRevision: reservedRevision,
                    rejection: .unavailable
                )
            }
        }
        return task
    }

    private func recentResult(_ requestID: UUID) -> RemoteControlResult? {
        recentResults.first(where: { $0.requestID == requestID })
    }

    private func loadContext() async -> CommandContext {
        let enabled = await sharing.isEnabled()
        let sourceRevision = await revisionReader.currentRemoteRevision()
        return CommandContext(enabled: enabled, revision: max(sourceRevision, minimumRevision))
    }

    private func preflightRejection(
        _ request: RemoteControlRequest,
        context: CommandContext
    ) -> RemoteControlRejection? {
        if !context.enabled { return .sharingDisabled }
        if request.expectedRevision != context.revision { return .staleRevision }
        return nil
    }

    private func rejection(
        _ request: RemoteControlRequest,
        _ reason: RemoteControlRejection,
        revision: UInt64
    ) -> RemoteControlResult {
        .init(
            requestID: request.requestID,
            accepted: false,
            authoritativeRevision: revision,
            rejection: reason
        )
    }

    private func remember(_ result: RemoteControlResult) -> RemoteControlResult {
        recentResults.append(result)
        if recentResults.count > maximumRecentResults {
            recentResults.removeFirst(recentResults.count - maximumRecentResults)
        }
        return result
    }
}

private struct CommandContext {
    let enabled: Bool
    let revision: UInt64
}
