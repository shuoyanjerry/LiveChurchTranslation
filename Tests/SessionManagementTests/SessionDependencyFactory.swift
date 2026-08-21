import ASRAPI
import ASRNormalizationCore
import AudioCaptureAPI
import AudioProcessingAPI
import GlossaryAPI
import ModelDownloadAPI
import ModelRuntimeAPI
import SessionManagement
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
            translator: components.translator,
            glossary: FakeGlossaryService(entries: glossary),
            modelDownloader: components.downloader,
            modelReporter: components.reporter,
            transcript: components.transcript,
            transcriptStore: components.store,
            settings: FakeSettingsStore(),
            logger: NoopAppLogger(),
            diagnostics: FakeDiagnosticsRecorder()
        )
    }

    private static let glossary = [
        GlossaryEntry(source: "因信称义", target: "justification by faith"),
        GlossaryEntry(source: "恩典", target: "grace"),
        GlossaryEntry(source: "救恩", target: "salvation"),
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

    init(
        permission: AudioCapturePermission,
        recognizedText: String,
        translationFails: Bool,
        storageFails: Bool,
        audioFrame: AudioFrame
    ) {
        capture = FakeAudioCaptureProvider(permission: permission, frames: [audioFrame])
        processor = FakeAudioProcessor()
        vad = FakeSegmentingVAD()
        asr = FakeMandarinASRProvider(text: recognizedText)
        translator = FakeHyTranslationProvider(shouldFail: translationFails)
        downloader = FakeModelDownloader()
        reporter = FakeModelRuntimeReporter()
        transcript = LiveTranscriptBuffer()
        store = FakeTranscriptStore(failAppend: storageFails)
    }
}
