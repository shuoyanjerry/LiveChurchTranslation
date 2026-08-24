import AudioImportAPI
import Foundation
import PersistenceAPI
import SettingsAPI

extension SessionLibraryViewModel {
    public func importAudio(
        from url: URL,
        mode: TranslationMode,
        sessionTitle: String? = nil,
        using importer: any AudioImporting,
        liveSessionIsRunning: Bool
    ) async {
        guard !isImporting else { return }
        guard !liveSessionIsRunning else {
            presentedError = "请先停止实时翻译。"
            return
        }
        beginAudioImportPresentation()
        defer { endAudioImportPresentation() }
        await processImport(
            from: url,
            mode: mode,
            sessionTitle: sessionTitle,
            using: importer
        )
    }

    public func retranscribeRetainedRecording(
        for summary: StoredSessionSummary,
        using importer: any AudioImporting,
        liveSessionIsRunning: Bool
    ) async {
        guard summary.hasIncompleteSpeechSegments, !isImporting else { return }
        guard !liveSessionIsRunning else {
            presentedError = "请先停止实时翻译。"
            return
        }
        guard let recordingURL = recordingURL(for: summary) else {
            presentedError = "完整录音暂时无法打开。现有资料没有受到影响。"
            return
        }
        guard let mode = summary.storedTranslationMode else {
            presentedError = "无法确定这份录音的语言方向。现有资料没有受到影响。"
            return
        }
        beginAudioImportPresentation()
        defer { endAudioImportPresentation() }
        guard !(await sessionIsActive(summary.id)) else {
            presentedError = "请先停止当前会议。"
            return
        }
        await processImport(
            from: recordingURL,
            mode: mode,
            sessionTitle: summary.retranscriptionTitle,
            using: importer
        )
    }

    private func processImport(
        from url: URL,
        mode: TranslationMode,
        sessionTitle: String?,
        using importer: any AudioImporting
    ) async {
        let baselineSessionIDs = try? await recentSessionSummaries().map(\.id)
        let knownSessionIDs = Set(baselineSessionIDs ?? sessions.map(\.id))
        let terminalState = await runImport(
            from: url,
            mode: mode,
            sessionTitle: sessionTitle,
            using: importer
        )
        let refreshed = await refreshAfterImport(
            knownSessionIDs: knownSessionIDs,
            savedSessionID: terminalState.savedSessionID,
            infersUniqueSession: baselineSessionIDs != nil && terminalState.infersUniqueSession
        )
        let finalState = reconciledState(
            terminalState,
            libraryRefreshed: refreshed,
            knownSessionIDs: knownSessionIDs,
            canReconcileUniqueSession: baselineSessionIDs != nil
        )
        if let message = finalState.message(libraryRefreshed: refreshed) {
            presentedError = message
        }
    }

    private func runImport(
        from url: URL,
        mode: TranslationMode,
        sessionTitle: String?,
        using importer: any AudioImporting
    ) async -> AudioImportTerminalState {
        do {
            try await importer.importAudio(
                from: url,
                mode: mode,
                sessionTitle: sessionTitle
            )
            return .saved
        } catch AudioImportError.cancelled {
            return .cancelled
        } catch AudioImportError.savedWithIncompleteTranscript(let sessionID) {
            return .savedIncomplete(sessionID: sessionID)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed
        }
    }

    private func refreshAfterImport(
        knownSessionIDs: Set<UUID>,
        savedSessionID: UUID?,
        infersUniqueSession: Bool
    ) async -> Bool {
        do {
            let refreshed = try await recentSessionSummaries()
            let explicitID = savedSessionID.flatMap { id in
                refreshed.contains { $0.id == id } ? id : nil
            }
            let newSessions = refreshed.filter { !knownSessionIDs.contains($0.id) }
            let inferredID = inferredSessionID(
                from: newSessions,
                savedSessionID: savedSessionID,
                isAllowed: infersUniqueSession
            )
            let retainedID = selectedSessionID.flatMap { id in
                refreshed.contains { $0.id == id } ? id : nil
            }
            await applyImportRefresh(
                sessions: refreshed,
                selectedSessionID: explicitID ?? inferredID ?? retainedID
            )
            return true
        } catch {
            return false
        }
    }

    private func inferredSessionID(
        from newSessions: [StoredSessionSummary],
        savedSessionID: UUID?,
        isAllowed: Bool
    ) -> UUID? {
        guard savedSessionID == nil, isAllowed, newSessions.count == 1 else { return nil }
        return newSessions[0].id
    }

    private func reconciledState(
        _ state: AudioImportTerminalState,
        libraryRefreshed: Bool,
        knownSessionIDs: Set<UUID>,
        canReconcileUniqueSession: Bool
    ) -> AudioImportTerminalState {
        let imported = sessions.filter { !knownSessionIDs.contains($0.id) }
        guard
            libraryRefreshed,
            canReconcileUniqueSession,
            state.infersUniqueSession,
            imported.count == 1,
            imported[0].integrity == .incomplete
        else { return state }
        return .savedIncomplete(sessionID: imported[0].id)
    }
}
