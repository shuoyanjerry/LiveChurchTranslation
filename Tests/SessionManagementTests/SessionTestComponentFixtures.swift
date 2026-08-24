import ASRAPI
import AudioCaptureAPI
@testable import SessionManagement
import SettingsAPI
import TranscriptCore

struct SessionTestConfiguration {
    let permission: AudioCapturePermission
    let recognizedText: String
    let recognizedTexts: [String]?
    let translationFails: Bool
    let translationRejectsFirstOutput: Bool
    let translationRejectedRequestIndices: Set<Int>
    let translationReviewedRequestIndices: Set<Int>
    let translationOutputs: [String]?
    let storageFails: Bool
    let finishFails: Bool
    let modelLoadFails: Bool
    let recognitionFails: Bool
    let recognitionError: ASRError?
    let recognitionErrorsByIndex: [Int: ASRError]
    let recognitionDelay: Duration?
    let recoveryStageFails: Bool
    let recordingAppendFails: Bool
    let recordingFinishFails: Bool
    let recordingRepairFails: Bool
    let recordingAppendDelay: Duration?
    let audioProcessingDelay: Duration?
    let modelPreparationDelay: Duration?
    let audioFrames: [AudioFrame]
    let holdsPermissionRequest: Bool
    let holdsCaptureOpen: Bool
    let emitsOnlyOnFlush: Bool
    let emitsEveryFrame: Bool
    let translationMode: TranslationMode
    let sentenceVisibilityClock: any SentenceVisibilityClock
}

struct SessionAudioComponents {
    let capture: FakeAudioCaptureProvider
    let processor: FakeAudioProcessor
    let vad: FakeSegmentingVAD

    init(_ configuration: SessionTestConfiguration) {
        capture = FakeAudioCaptureProvider(
            permission: configuration.permission,
            frames: configuration.audioFrames,
            holdsPermissionRequest: configuration.holdsPermissionRequest,
            holdsStreamOpen: configuration.holdsCaptureOpen
        )
        processor = FakeAudioProcessor(delay: configuration.audioProcessingDelay)
        vad = FakeSegmentingVAD(
            emitsOnlyOnFlush: configuration.emitsOnlyOnFlush,
            emitsEveryFrame: configuration.emitsEveryFrame
        )
    }
}

struct SessionInferenceComponents {
    let asr: FakeMandarinASRProvider
    let translator: FakeHyTranslationProvider
    let downloader: FakeModelDownloader
    let reporter: FakeModelRuntimeReporter

    init(_ configuration: SessionTestConfiguration) {
        let inputs = FakeASRInputs(
            text: configuration.recognizedText,
            loadFails: configuration.modelLoadFails,
            recognitionFails: configuration.recognitionFails,
            recognitionError: configuration.recognitionError,
            recognitionErrorsByIndex: configuration.recognitionErrorsByIndex,
            recognitionDelay: configuration.recognitionDelay
        )
        asr = Self.makeASR(texts: configuration.recognizedTexts, configuration: inputs)
        translator = FakeHyTranslationProvider(
            shouldFail: configuration.translationFails,
            rejectsFirstOutput: configuration.translationRejectsFirstOutput,
            rejectedRequestIndices: configuration.translationRejectedRequestIndices,
            reviewedRequestIndices: configuration.translationReviewedRequestIndices,
            outputs: configuration.translationOutputs
        )
        downloader = FakeModelDownloader(delay: configuration.modelPreparationDelay)
        reporter = FakeModelRuntimeReporter()
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
}

struct SessionStorageComponents {
    let transcript: LiveTranscriptBuffer
    let store: FakeTranscriptStore
    let recordingStore: FakeSessionRecordingStore
    let recoveryStore: FakeUtteranceRecoveryStore
    let diagnostics: FakeDiagnosticsRecorder

    init(_ configuration: SessionTestConfiguration) {
        transcript = LiveTranscriptBuffer()
        store = FakeTranscriptStore(
            failAppend: configuration.storageFails,
            failFinish: configuration.finishFails
        )
        recordingStore = FakeSessionRecordingStore(
            failAppendAfterWrite: configuration.recordingAppendFails,
            failFinish: configuration.recordingFinishFails,
            failRepair: configuration.recordingRepairFails,
            appendDelay: configuration.recordingAppendDelay
        )
        recoveryStore = FakeUtteranceRecoveryStore(stageFails: configuration.recoveryStageFails)
        diagnostics = FakeDiagnosticsRecorder()
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
