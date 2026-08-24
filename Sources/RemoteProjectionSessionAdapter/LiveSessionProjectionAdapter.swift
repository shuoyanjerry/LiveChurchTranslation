import Foundation
import RemoteSharingAPI
import SessionManagementAPI
import TranscriptAPI

public actor LiveSessionProjectionAdapter {
    private let controller: any LiveSessionController
    private let projection: any RemoteProjectionUpdating
    private var observationTask: Task<Void, Never>?
    private var projectedSessionID: UUID?
    private var projectedEntryIDs: Set<UUID> = []
    private var sourceLanguage: String?
    private var targetLanguage: String?

    public init(
        controller: any LiveSessionController,
        projection: any RemoteProjectionUpdating
    ) {
        self.controller = controller
        self.projection = projection
    }

    public func start() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self, controller] in
            for await event in await controller.events() {
                await self?.receive(event)
            }
        }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
    }

    private func receive(_ event: LiveSessionEvent) async {
        switch event {
        case .stateChanged(let snapshot):
            await project(snapshot)
        case .transcriptAppended(let entry):
            await project(entry)
        case .recoverableError:
            break
        }
    }

    private func project(_ snapshot: LiveSessionSnapshot) async {
        sourceLanguage = snapshot.sourceLanguage
        targetLanguage = snapshot.targetLanguage
        if let sessionID = snapshot.sessionID, sessionID != projectedSessionID {
            projectedSessionID = sessionID
            projectedEntryIDs.removeAll(keepingCapacity: true)
            await projection.beginSession(
                id: sessionID,
                message: "正在准备本地翻译",
                sourceLanguage: snapshot.sourceLanguage,
                targetLanguage: snapshot.targetLanguage
            )
        }
        for entry in snapshot.transcript where !projectedEntryIDs.contains(entry.id) {
            await project(entry)
        }
        await projection.updateState(
            phase: RemoteSessionPresentation.phase(snapshot.phase),
            message: RemoteSessionPresentation.message(snapshot.phase),
            sourceLanguage: snapshot.sourceLanguage,
            targetLanguage: snapshot.targetLanguage
        )
    }

    private func project(_ entry: TranscriptEntry) async {
        guard !projectedEntryIDs.contains(entry.id) else { return }
        do {
            try await projection.upsert(
                RemoteProjectionEntryInput(
                    id: entry.id,
                    sequence: entry.sequence,
                    sourceText: entry.sourceText,
                    targetText: entry.targetText,
                    createdAt: entry.createdAt,
                    startedMilliseconds: entry.startedMilliseconds,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
            )
            projectedEntryIDs.insert(entry.id)
        } catch {
            return
        }
    }
}
