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

    init(
        permission: AudioCapturePermission,
        recognizedText: String,
        recognizedTexts: [String]? = nil,
        translationFails: Bool,
        translationRejectsFirstOutput: Bool,
        translationRejectedRequestIndices: Set<Int>,
        translationReviewedRequestIndices: Set<Int>,
        storageFails: Bool,
        finishFails: Bool,
        modelLoadFails: Bool,
        recognitionFails: Bool,
        recognitionError: ASRError? = nil,
        recognitionErrorsByIndex: [Int: ASRError] = [:],
        recognitionDelay: Duration? = nil,
        recoveryStageFails: Bool = false,
        recordingAppendFails: Bool = false,
        recordingFinishFails: Bool = false,
        recordingRepairFails: Bool = false,
        modelPreparationDelay: Duration?,
        audioFrames: [AudioFrame],
        holdsPermissionRequest: Bool,
        holdsCaptureOpen: Bool,
        emitsOnlyOnFlush: Bool,
        emitsEveryFrame: Bool = false,
        translationMode: TranslationMode = .mandarinToEnglish,
        sentenceVisibilityClock: any SentenceVisibilityClock
    ) {
        capture = FakeAudioCaptureProvider(
            permission: permission,
            frames: audioFrames,
            holdsPermissionRequest: holdsPermissionRequest,
            holdsStreamOpen: holdsCaptureOpen
        )
        processor = FakeAudioProcessor()
        vad = FakeSegmentingVAD(
            emitsOnlyOnFlush: emitsOnlyOnFlush,
            emitsEveryFrame: emitsEveryFrame
        )
        let asrInputs = FakeASRInputs(
            text: recognizedText,
            loadFails: modelLoadFails,
            recognitionFails: recognitionFails,
            recognitionError: recognitionError,
            recognitionErrorsByIndex: recognitionErrorsByIndex,
            recognitionDelay: recognitionDelay
        )
        asr = Self.makeASR(texts: recognizedTexts, configuration: asrInputs)
        let rejectedIndices = translationRejectedRequestIndices
        translator = Self.makeTranslator(
            translationFails,
            translationRejectsFirstOutput,
            rejectedIndices,
            translationReviewedRequestIndices
        )
        downloader = FakeModelDownloader(delay: modelPreparationDelay)
        reporter = FakeModelRuntimeReporter()
        transcript = LiveTranscriptBuffer()
        store = FakeTranscriptStore(failAppend: storageFails, failFinish: finishFails)
        recordingStore = FakeSessionRecordingStore(
            failAppendAfterWrite: recordingAppendFails,
            failFinish: recordingFinishFails,
            failRepair: recordingRepairFails
        )
        recoveryStore = FakeUtteranceRecoveryStore(stageFails: recoveryStageFails)
        diagnostics = FakeDiagnosticsRecorder()
        self.sentenceVisibilityClock = sentenceVisibilityClock
        self.translationMode = translationMode
    }

    private static func makeASR(
        texts: [String]?,
        configuration: FakeASRInputs
    ) -> FakeMandarinASRProvider {
        guard let texts else {
            return FakeMandarinASRProvider(
                text: configuration.text,
                loadFails: configuration.loadFails,
                recognitionFails: configuration.recognitionFails,
                recognitionError: configuration.recognitionError,
                recognitionErrorsByIndex: configuration.recognitionErrorsByIndex,
                recognitionDelay: configuration.recognitionDelay
            )
        }
        return FakeMandarinASRProvider(texts: texts)
    }

    private static func makeTranslator(
        _ shouldFail: Bool,
        _ rejectsFirstOutput: Bool,
        _ rejectedRequestIndices: Set<Int>,
        _ reviewedRequestIndices: Set<Int>
    ) -> FakeHyTranslationProvider {
        FakeHyTranslationProvider(
            shouldFail: shouldFail,
            rejectsFirstOutput: rejectsFirstOutput,
            rejectedRequestIndices: rejectedRequestIndices,
            reviewedRequestIndices: reviewedRequestIndices
        )
    }
}

private struct FakeASRInputs {
    let text: String
    let loadFails: Bool
    let recognitionFails: Bool
    let recognitionError: ASRError?
    let recognitionErrorsByIndex: [Int: ASRError]
    let recognitionDelay: Duration?
}
