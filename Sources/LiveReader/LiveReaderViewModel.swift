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
    @Published public internal(set) var glossaryEntries: [GlossaryEntry] = []
    @Published public var settings = AppSettings.defaults
    @Published public var presentedError: String?
    @Published public var presentsRecordingNotice = false
    @Published public private(set) var recordingStartedAt: Date?
    @Published public private(set) var externalSessionControlLock = false

    private let controller: any LiveSessionController
    private let capture: any AudioCaptureProvider
    let glossary: any GlossaryService
    let settingsStore: any SettingsStore
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

    public var sessionControlsLocked: Bool {
        isRunning || externalSessionControlLock
    }

    public func setExternalSessionControlLock(_ isLocked: Bool) {
        externalSessionControlLock = isLocked
        if isLocked {
            presentsRecordingNotice = false
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
        } else if externalSessionControlLock {
            presentedError = "Wait for the current audio import to finish before starting live capture."
        } else {
            presentsRecordingNotice = true
        }
    }

    public func startRecordingAndTranslation() async {
        presentsRecordingNotice = false
        guard !sessionControlsLocked else { return }
        guard await saveSettings() else { return }
        await controller.start(inputDeviceID: selectedInputID)
    }

    public func selectTranslationMode(_ mode: TranslationMode) async {
        guard !sessionControlsLocked, mode != settings.translationMode else { return }
        let previous = settings
        settings.translationMode = mode
        if !(await saveSettings()) {
            settings = previous
        }
    }

    public func selectAudioInput(_ id: AudioInputID?) async {
        guard !sessionControlsLocked, id != selectedInputID else { return }
        let previousID = selectedInputID
        selectedInputID = id
        if !(await saveSettings()) {
            selectedInputID = previousID
        }
    }
}

extension LiveReaderViewModel {
    private func receive(_ event: LiveSessionEvent) {
        switch event {
        case .stateChanged(let snapshot):
            self.snapshot = snapshot
            recordingStartedAt = snapshot.captureStartedAt
        case .transcriptAppended(let entry):
            guard !snapshot.transcript.contains(where: { $0.id == entry.id }) else { return }
            snapshot = LiveSessionSnapshot(
                sessionID: snapshot.sessionID,
                phase: snapshot.phase,
                transcript: snapshot.transcript + [entry],
                captureStartedAt: snapshot.captureStartedAt,
                sourceLanguage: snapshot.sourceLanguage,
                targetLanguage: snapshot.targetLanguage,
                modelStatus: snapshot.modelStatus,
                statusMessage: snapshot.statusMessage,
                issues: snapshot.issues,
                finalizationOutcome: snapshot.finalizationOutcome
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
