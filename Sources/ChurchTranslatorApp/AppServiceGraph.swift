import ASRNormalizationCore
import ASRQwen3
import AudioCaptureAPI
import AudioCaptureAVFoundation
import AudioProcessingCore
import DiagnosticsCore
import DiscourseResolutionCore
import GlossaryCore
import GlossaryFileSystem
import LoggingOSLog
import ModelDownloadHTTP
import ModelRuntimeCore
import PersistenceFileSystem
import RecordingFileSystem
import SessionManagement
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
    let modelPreparation: InferenceModelPreparationCoordinator

    private let logger: UnifiedLogger
    private let reporter: ModelRuntimeReporter
    private let downloader: HTTPModelDownloader
    private let asr: Qwen3ASRProvider
    private let translator: HyMT2TranslationProvider

    init(directories: AppDirectories, models: SessionModelDescriptors) throws {
        let logger = UnifiedLogger(subsystem: "com.shuoyan.LiveChurchTranslation")
        let reporter = ModelRuntimeReporter()
        let downloader = try HTTPModelDownloader(
            manifests: ProductionModelCatalog.manifests(),
            rootDirectory: directories.models,
            locationStore: LocalModelLocationStore(root: directories.models),
            runtimeReporter: reporter
        )
        let asr = Qwen3ASRProvider()
        let translator = HyMT2TranslationProvider(
            helperExecutableURL: HelperExecutableLocator.llamaServer()
        )
        capture = AVFoundationAudioCaptureProvider()
        glossary = DefaultGlossaryService(
            repository: FileGlossaryRepository(directory: directories.glossary)
        )
        settings = UserDefaultsSettingsStore(
            suiteName: "com.shuoyan.LiveChurchTranslation"
        )
        transcripts = FileTranscriptStore(root: directories.transcripts)
        recordings = try FileSessionRecordingStore(root: directories.transcripts)
        self.logger = logger
        self.reporter = reporter
        self.downloader = downloader
        self.asr = asr
        self.translator = translator
        modelPreparation = InferenceModelPreparationCoordinator(
            modelDownloader: downloader,
            modelReporter: reporter,
            asr: asr,
            translator: translator,
            models: models
        )
    }

    func makeSessionDependencies(
        directories: AppDirectories,
        capture captureOverride: (any AudioCaptureProvider)? = nil
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
            recoveryStore: try FileUtteranceRecoveryStore(root: directories.recovery),
            settings: settings,
            logger: logger,
            diagnostics: InMemoryDiagnosticsRecorder(
                logger: logger,
                exportDirectory: directories.diagnostics
            )
        )
    }
}
