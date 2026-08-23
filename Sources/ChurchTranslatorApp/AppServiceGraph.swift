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

    private let logger: UnifiedLogger
    private let reporter: ModelRuntimeReporter
    private let downloader: HTTPModelDownloader

    init(directories: AppDirectories) throws {
        let logger = UnifiedLogger(subsystem: "com.shuoyan.LiveChurchTranslation")
        let reporter = ModelRuntimeReporter()
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
        downloader = try HTTPModelDownloader(
            manifests: ProductionModelCatalog.manifests(),
            rootDirectory: directories.models,
            locationStore: LocalModelLocationStore(root: directories.models),
            runtimeReporter: reporter
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
            asr: Qwen3ASRProvider(),
            asrNormalizer: RuleBasedASRTextNormalizer(),
            discourseResolver: DiscourseResolver(),
            translator: HyMT2TranslationProvider(
                helperExecutableURL: HelperExecutableLocator.llamaServer()
            ),
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
