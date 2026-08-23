import AppKit
import Combine
import Foundation
import PersistenceAPI
import SettingsAPI
import TranscriptAPI
import UtteranceRecoveryAPI

@MainActor
public final class SessionLibraryViewModel: ObservableObject {
    @Published public private(set) var sessions: [StoredSessionSummary] = []
    @Published public private(set) var selectedSession: TranscriptSession?
    @Published public private(set) var selectedSessionIsActive = false
    @Published public var selectedSessionID: UUID?
    @Published public var searchText = ""
    @Published public var presentedError: String?
    @Published public private(set) var isImporting = false

    private let store: any TranscriptStore
    private let recoveryArtifacts: any SessionRecoveryArtifactDeleting

    public init(
        store: any TranscriptStore,
        recoveryArtifacts: any SessionRecoveryArtifactDeleting
    ) {
        self.store = store
        self.recoveryArtifacts = recoveryArtifacts
    }

    public var filteredSessions: [StoredSessionSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }
        return sessions.filter {
            $0.displayTitle.localizedStandardContains(query)
                || $0.languagePair.localizedStandardContains(query)
        }
    }

    public var selectedSummary: StoredSessionSummary? {
        sessions.first { $0.id == selectedSessionID }
    }

    public func load() async {
        do {
            sessions = try await store.recentSessions(limit: 500)
            if selectedSessionID == nil { selectedSessionID = sessions.first?.id }
            await loadSelection()
        } catch {
            presentedError = error.localizedDescription
        }
    }

    public func select(_ id: UUID?) async {
        selectedSessionID = id
        await loadSelection()
    }

    public func deleteSelected() async {
        guard let id = selectedSessionID else { return }
        do {
            guard !(await store.isSessionActive(sessionID: id)) else {
                selectedSessionIsActive = true
                throw TranscriptStoreError.sessionActive
            }
            try await recoveryArtifacts.deleteArtifacts(for: id)
            try await store.delete(sessionID: id)
            selectedSessionID = nil
            selectedSession = nil
            selectedSessionIsActive = false
            await load()
        } catch {
            presentedError = error.localizedDescription
        }
    }

    public func importAudio(
        from url: URL,
        using importer: any AudioImporting,
        liveSessionIsRunning: Bool
    ) async {
        guard !liveSessionIsRunning else {
            presentedError = AudioImportError.liveSessionRunning.localizedDescription
            return
        }
        isImporting = true
        defer { isImporting = false }
        do {
            try await importer.importAudio(from: url)
            selectedSessionID = nil
            await load()
        } catch {
            presentedError = error.localizedDescription
        }
    }

    public func revealSelected() {
        guard let summary = selectedSummary else { return }
        NSWorkspace.shared.activateFileViewerSelecting([summary.location])
    }

    public func recordingURL(for summary: StoredSessionSummary) -> URL? {
        safeFile(named: "recording.caf", in: summary.location)
            ?? safeFile(named: "recording.wav", in: summary.location)
    }

    public func transcriptURL(for summary: StoredSessionSummary) -> URL? {
        safeFile(named: "transcript.md", in: summary.location)
    }

    private func loadSelection() async {
        guard let id = selectedSessionID else {
            selectedSession = nil
            selectedSessionIsActive = false
            return
        }
        do {
            async let session = store.load(sessionID: id)
            async let active = store.isSessionActive(sessionID: id)
            selectedSession = try await session
            selectedSessionIsActive = await active
        } catch {
            selectedSession = nil
            selectedSessionIsActive = false
            presentedError = error.localizedDescription
        }
    }

    private func safeFile(named name: String, in directory: URL) -> URL? {
        let url = directory.appending(path: name)
        guard
            let values = try? url.resourceValues(
                forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            ), values.isRegularFile == true, values.isSymbolicLink != true
        else { return nil }
        return url
    }
}
