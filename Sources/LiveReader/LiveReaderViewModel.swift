import AudioCaptureAPI
import Combine
import Foundation
import GlossaryAPI
import SessionManagementAPI
import SettingsAPI
import TranscriptAPI

@MainActor
public final class LiveReaderViewModel: ObservableObject {
    @Published public private(set) var snapshot = LiveSessionSnapshot(
        sessionID: nil,
        phase: .idle,
        transcript: [],
        modelStatus: nil,
        statusMessage: "Ready"
    )
    @Published public private(set) var devices: [AudioInputDevice] = []
    @Published public var selectedInputID: AudioInputID?
    @Published public private(set) var glossaryEntries: [GlossaryEntry] = []
    @Published public var settings = AppSettings.defaults
    @Published public var presentedError: String?

    private let controller: any LiveSessionController
    private let capture: any AudioCaptureProvider
    private let glossary: any GlossaryService
    private let settingsStore: any SettingsStore
    private var eventTask: Task<Void, Never>?

    public init(
        controller: any LiveSessionController,
        capture: any AudioCaptureProvider,
        glossary: any GlossaryService,
        settingsStore: any SettingsStore
    ) {
        self.controller = controller
        self.capture = capture
        self.glossary = glossary
        self.settingsStore = settingsStore
    }

    deinit {
        eventTask?.cancel()
    }

    public var isRunning: Bool {
        switch snapshot.phase {
        case .idle, .failed: false
        default: true
        }
    }

    public func load() async {
        #if DEBUG
            if loadDesignQAPreviewIfRequested() { return }
        #endif
        eventTask?.cancel()
        eventTask = Task { [weak self, controller] in
            let stream = await controller.events()
            for await event in stream {
                guard !Task.isCancelled else { return }
                self?.receive(event)
            }
        }
        do {
            settings = try await settingsStore.load()
            selectedInputID = settings.selectedAudioDeviceID.map { AudioInputID(rawValue: $0) }
            glossaryEntries = try await glossary.snapshot().entries
            devices = try await capture.availableInputs()
        } catch {
            presentedError = error.localizedDescription
        }
    }

    public func toggleSession() async {
        if isRunning {
            await controller.stop()
        } else {
            await saveSettings()
            await controller.start(inputDeviceID: selectedInputID)
        }
    }
}

extension LiveReaderViewModel {
    @discardableResult
    public func saveGlossary(_ entries: [GlossaryEntry]) async -> Bool {
        do {
            try await glossary.replace(with: entries)
            glossaryEntries = try await glossary.snapshot().entries
            return true
        } catch {
            presentedError = error.localizedDescription
            return false
        }
    }

    public func restoreGlossary() async -> [GlossaryEntry]? {
        do {
            try await glossary.restoreDefaults()
            glossaryEntries = try await glossary.snapshot().entries
            return glossaryEntries
        } catch {
            presentedError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    public func saveSettings() async -> Bool {
        settings.selectedAudioDeviceID = selectedInputID?.rawValue
        do {
            try await settingsStore.save(settings)
            return true
        } catch {
            presentedError = error.localizedDescription
            return false
        }
    }

    private func receive(_ event: LiveSessionEvent) {
        switch event {
        case .stateChanged(let snapshot):
            self.snapshot = snapshot
        case .transcriptAppended(let entry):
            guard !snapshot.transcript.contains(where: { $0.id == entry.id }) else { return }
            snapshot = LiveSessionSnapshot(
                sessionID: snapshot.sessionID,
                phase: snapshot.phase,
                transcript: snapshot.transcript + [entry],
                modelStatus: snapshot.modelStatus,
                statusMessage: snapshot.statusMessage
            )
        case .recoverableError(let message):
            presentedError = message
        }
    }

    #if DEBUG
        private func loadDesignQAPreviewIfRequested() -> Bool {
            guard UserDefaults.standard.bool(forKey: "QuietReaderDesignPreview") else {
                return false
            }
            settings = AppSettings(readerFontSize: 30, showSourceText: false)
            snapshot = LiveSessionSnapshot(
                sessionID: nil,
                phase: .idle,
                transcript: DesignQAPreviewFixture.transcript,
                modelStatus: nil,
                statusMessage: "Transcript saved"
            )
            return true
        }

    #endif
}
