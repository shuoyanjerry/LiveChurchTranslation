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
    @Published public private(set) var modelPreparationSnapshot = ModelPreparationSnapshot(
        phase: .idle,
        message: "正在准备本地语音与翻译模型…"
    )

    let controller: any LiveSessionController
    let modelPreparation: any ModelPreparationController
    private let capture: any AudioCaptureProvider
    let glossary: any GlossaryService
    let settingsStore: any SettingsStore
    private var eventTask: Task<Void, Never>?
    private var modelEventTask: Task<Void, Never>?
    private var modelPreparationTask: Task<Void, Never>?

    public init(
        controller: any LiveSessionController,
        modelPreparation: any ModelPreparationController,
        capture: any AudioCaptureProvider,
        glossary: any GlossaryService,
        settingsStore: any SettingsStore
    ) {
        self.controller = controller
        self.modelPreparation = modelPreparation
        self.capture = capture
        self.glossary = glossary
        self.settingsStore = settingsStore
    }

    deinit {
        eventTask?.cancel()
        modelEventTask?.cancel()
        modelPreparationTask?.cancel()
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
        modelEventTask?.cancel()
        modelEventTask = Task { [weak self, modelPreparation] in
            for await snapshot in await modelPreparation.modelPreparationEvents() {
                guard !Task.isCancelled else { return }
                self?.modelPreparationSnapshot = snapshot
            }
        }
        modelPreparationTask?.cancel()
        modelPreparationTask = Task { [modelPreparation] in
            await modelPreparation.prepareModels()
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
