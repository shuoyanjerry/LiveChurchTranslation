import ASRNormalizationCore
import ASRQwen3
import AudioCaptureAPI
import AudioCaptureAVFoundation
import AudioProcessingCore
import DiagnosticsCore
import DiscourseResolutionCore
import Foundation
import GlossaryCore
import GlossaryFileSystem
import LoggingOSLog
import ModelDownloadAPI
import ModelDownloadHTTP
import ModelRuntimeAPI
import ModelRuntimeCore
import PersistenceFileSystem
import RecordingFileSystem
import SessionManagement
import SettingsAPI
import SettingsUserDefaults
import TranscriptCore
import TranslationHyMT2
import UtteranceRecoveryFileSystem
import VADCore
import VADWebRTC

@MainActor
struct AppServiceGraph {
    let capture: AVFoundationAudioCaptureProvider
    let glossary: DefaultGlossaryService
    let settings: UserDefaultsSettingsStore
    let transcripts: FileTranscriptStore
    let recordings: FileSessionRecordingStore
    let recovery: FileUtteranceRecoveryStore
    let modelPreparation: InferenceModelPreparationCoordinator
    let transcriptionModelPreparation: InferenceModelPreparationCoordinator
    let diagnostics: InMemoryDiagnosticsRecorder

    private let logger: UnifiedLogger
    private let reporter: ModelRuntimeReporter
    private let downloader: any ModelDownloadProvider
    private let asr: Qwen3ASRProvider
    private let translator: HyMT2TranslationProvider

    init(directories: AppDirectories, models: SessionModelDescriptors) throws {
        let logger = UnifiedLogger(subsystem: "com.shuoyan.LiveChurchTranslation")
        let reporter = ModelRuntimeReporter()
        let diagnostics = Self.makeDiagnostics(logger: logger, directory: directories.diagnostics)
        let downloader = try Self.makeModelProvider(
            cacheRoot: directories.models,
            reporter: reporter
        )
        let asr = Qwen3ASRProvider()
        let translator = HyMT2TranslationProvider(
            helperExecutableURL: HelperExecutableLocator.llamaServer()
        )
        capture = AVFoundationAudioCaptureProvider()
        glossary = DefaultGlossaryService(
            repository: FileGlossaryRepository(directory: directories.glossary)
        )
        settings = UserDefaultsSettingsStore()
        transcripts = FileTranscriptStore(root: directories.transcripts)
        recordings = try FileSessionRecordingStore(root: directories.transcripts)
        recovery = try FileUtteranceRecoveryStore(root: directories.recovery)
        self.logger = logger
        self.reporter = reporter
        self.diagnostics = diagnostics
        self.downloader = downloader
        self.asr = asr
        self.translator = translator
        (modelPreparation, transcriptionModelPreparation) = Self.makeModelPreparations(
            downloader: downloader,
            reporter: reporter,
            asr: asr,
            translator: translator,
            models: models
        )
    }

    private static func makeDiagnostics(
        logger: UnifiedLogger,
        directory: URL
    ) -> InMemoryDiagnosticsRecorder {
        InMemoryDiagnosticsRecorder(logger: logger, exportDirectory: directory)
    }

    private static func makeModelProvider(
        cacheRoot: URL,
        reporter: any ModelRuntimeReporting
    ) throws -> any ModelDownloadProvider {
        let manifests = try ProductionModelCatalog.manifests()
        #if DEBUG
            if let bundledRoot = BundledModelLocator.modelsRoot() {
                if FileManager.default.fileExists(atPath: bundledRoot.path) {
                    return try BundledModelProvider(
                        manifests: manifests,
                        rootDirectory: bundledRoot,
                        runtimeReporter: reporter
                    )
                }
            }
            return try HTTPModelDownloader(
                manifests: manifests,
                rootDirectory: cacheRoot,
                locationStore: LocalModelLocationStore(root: cacheRoot),
                runtimeReporter: reporter
            )
        #else
            guard let bundledRoot = BundledModelLocator.modelsRoot() else {
                throw BundledModelError.invalidRoot
            }
            return try BundledModelProvider(
                manifests: manifests,
                rootDirectory: bundledRoot,
                runtimeReporter: reporter
            )
        #endif
    }

    func makeSessionDependencies(
        directories: AppDirectories,
        capture captureOverride: (any AudioCaptureProvider)? = nil,
        settings settingsOverride: (any SettingsStore)? = nil
    ) throws -> LiveSessionDependencies {
        LiveSessionDependencies(
            capture: captureOverride ?? capture,
            audioProcessor: try MonoResamplingAudioProcessor(),
            vad: try CalibratedVoiceActivityDetector(
                classifier: try WebRTCVoiceActivityClassifier()
            ),
            asr: asr,
            asrNormalizer: RuleBasedASRTextNormalizer(),
            discourseResolver: DiscourseResolver(),
            translator: translator,
            glossary: glossary,
            modelDownloader: downloader,
            modelReporter: reporter,
            transcript: LiveTranscriptBuffer(),
            transcriptStore: transcripts,
            recordingStore: recordings,
            recoveryStore: recovery,
            settings: settingsOverride ?? settings,
            logger: logger,
            diagnostics: diagnostics
        )
    }
}
