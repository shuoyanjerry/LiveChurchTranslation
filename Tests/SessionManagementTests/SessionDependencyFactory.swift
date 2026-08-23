import ASRAPI
import ASRNormalizationCore
import AudioCaptureAPI
import AudioProcessingAPI
import DiscourseResolutionCore
import GlossaryAPI
import ModelDownloadAPI
import ModelRuntimeAPI
@testable import SessionManagement
import SettingsAPI
import TranscriptAPI
import TranscriptCore
import TranslationAPI
import VADAPI

enum SessionDependencyFactory {
    static func make(_ components: SessionTestComponents) -> LiveSessionDependencies {
        LiveSessionDependencies(
            capture: components.capture,
            audioProcessor: components.processor,
            vad: components.vad,
            asr: components.asr,
            asrNormalizer: RuleBasedASRTextNormalizer(),
            discourseResolver: DiscourseResolver(),
            translator: components.translator,
            glossary: FakeGlossaryService(entries: glossary),
            modelDownloader: components.downloader,
            modelReporter: components.reporter,
            transcript: components.transcript,
            transcriptStore: components.store,
            recordingStore: components.recordingStore,
            recoveryStore: components.recoveryStore,
            settings: FakeSettingsStore(
                settings: AppSettings(translationMode: components.translationMode)
            ),
            logger: NoopAppLogger(),
            diagnostics: components.diagnostics
        )
    }

    private static let glossary = [
        GlossaryEntry(
            source: "因信称义",
            target: "justification by faith",
            enforcement: .required
        ),
        GlossaryEntry(source: "恩典", target: "grace", enforcement: .required),
        GlossaryEntry(
            source: "救恩",
            target: "salvation",
            sourceAliases: ["得救"],
            targetVariants: ["saved", "saving"],
            enforcement: .required
        ),
        GlossaryEntry(source: "在圣灵里成圣", target: "be sanctified in the Holy Spirit"),
        GlossaryEntry(
            source: "洗礼",
            target: "baptism",
            recognitionAliases: ["喜礼"]
        ),
        GlossaryEntry(source: "我们", target: "we", isEnabled: false),
    ]
}

struct SessionTestComponents {
    let capture: FakeAudioCaptureProvider
    let processor: FakeAudioProcessor
    let vad: FakeSegmentingVAD
    let asr: FakeMandarinASRProvider
    let translator: FakeHyTranslationProvider
    let downloader: FakeModelDownloader
    let reporter: FakeModelRuntimeReporter
    let transcript: LiveTranscriptBuffer
    let store: FakeTranscriptStore
    let recordingStore: FakeSessionRecordingStore
    let recoveryStore: FakeUtteranceRecoveryStore
    let diagnostics: FakeDiagnosticsRecorder
    let sentenceVisibilityClock: any SentenceVisibilityClock
    let translationMode: TranslationMode

    init(configuration: SessionTestConfiguration) {
        let audio = SessionAudioComponents(configuration)
        let inference = SessionInferenceComponents(configuration)
        let storage = SessionStorageComponents(configuration)
        capture = audio.capture
        processor = audio.processor
        vad = audio.vad
        asr = inference.asr
        translator = inference.translator
        downloader = inference.downloader
        reporter = inference.reporter
        transcript = storage.transcript
        store = storage.store
        recordingStore = storage.recordingStore
        recoveryStore = storage.recoveryStore
        diagnostics = storage.diagnostics
        sentenceVisibilityClock = configuration.sentenceVisibilityClock
        translationMode = configuration.translationMode
    }
}
