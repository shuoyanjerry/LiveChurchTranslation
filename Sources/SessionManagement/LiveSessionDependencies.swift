import ASRAPI
import ASRNormalizationAPI
import AudioCaptureAPI
import AudioProcessingAPI
import DiagnosticsAPI
import GlossaryAPI
import LoggingAPI
import ModelDownloadAPI
import ModelRuntimeAPI
import PersistenceAPI
import SettingsAPI
import TranscriptAPI
import TranslationAPI
import VADAPI

public struct LiveSessionDependencies: Sendable {
    let capture: any AudioCaptureProvider
    let audioProcessor: any AudioProcessor
    let vad: any VoiceActivityDetector
    let asr: any ASRProvider
    let asrNormalizer: any ASRTextNormalizer
    let translator: any TranslationProvider
    let glossary: any GlossaryService
    let modelDownloader: any ModelDownloadProvider
    let modelReporter: any ModelRuntimeReporting
    let transcript: any TranscriptBuffer
    let transcriptStore: any TranscriptStore
    let settings: any SettingsStore
    let logger: any AppLogger
    let diagnostics: any DiagnosticsRecorder

    public init(
        capture: any AudioCaptureProvider,
        audioProcessor: any AudioProcessor,
        vad: any VoiceActivityDetector,
        asr: any ASRProvider,
        asrNormalizer: any ASRTextNormalizer,
        translator: any TranslationProvider,
        glossary: any GlossaryService,
        modelDownloader: any ModelDownloadProvider,
        modelReporter: any ModelRuntimeReporting,
        transcript: any TranscriptBuffer,
        transcriptStore: any TranscriptStore,
        settings: any SettingsStore,
        logger: any AppLogger,
        diagnostics: any DiagnosticsRecorder
    ) {
        self.capture = capture
        self.audioProcessor = audioProcessor
        self.vad = vad
        self.asr = asr
        self.asrNormalizer = asrNormalizer
        self.translator = translator
        self.glossary = glossary
        self.modelDownloader = modelDownloader
        self.modelReporter = modelReporter
        self.transcript = transcript
        self.transcriptStore = transcriptStore
        self.settings = settings
        self.logger = logger
        self.diagnostics = diagnostics
    }
}
