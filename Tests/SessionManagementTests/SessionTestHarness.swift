import AudioCaptureAPI
import ASRAPI
import ASRNormalizationCore
import Foundation
import GlossaryAPI
import ModelRuntimeAPI
@testable import SessionManagement
import SessionManagementAPI
import SettingsAPI
import Testing
import TranscriptAPI
import TranscriptCore
import TranslationAPI

struct SessionTestHarness {
    let capture: FakeAudioCaptureProvider
    let processor: FakeAudioProcessor
    let vad: FakeSegmentingVAD
    let asr: FakeMandarinASRProvider
    let translator: FakeHyTranslationProvider
    let downloader: FakeModelDownloader
    let transcript: LiveTranscriptBuffer
    let store: FakeTranscriptStore
    let recordingStore: FakeSessionRecordingStore
    let recoveryStore: FakeUtteranceRecoveryStore
    let diagnostics: FakeDiagnosticsRecorder
    let coordinator: LiveSessionCoordinator

    init(
        permission: AudioCapturePermission = .authorized,
        recognizedText: String = "我们因信称义，这是恩典。",
        recognizedTexts: [String]? = nil,
        translationFails: Bool = false,
        storageFails: Bool = false,
        finishFails: Bool = false,
        modelLoadFails: Bool = false,
        recognitionFails: Bool = false,
        recognitionError: ASRError? = nil,
        recognitionDelay: Duration? = nil,
        recoveryStageFails: Bool = false,
        recordingAppendFails: Bool = false,
        recordingFinishFails: Bool = false,
        recordingRepairFails: Bool = false,
        modelPreparationDelay: Duration? = nil,
        holdsPermissionRequest: Bool = false,
        holdsCaptureOpen: Bool = false,
        emitsOnlyOnFlush: Bool = false,
        emitsEveryFrame: Bool = false,
        translationMode: TranslationMode = .mandarinToEnglish,
        audioFrames: [AudioFrame]? = nil,
        sessionKind: TranscriptSessionKind = .live,
        sentenceVisibilityClock: (any SentenceVisibilityClock)? = nil
    ) {
        self.init(
            components: SessionTestComponents(
                permission: permission,
                recognizedText: recognizedText,
                recognizedTexts: recognizedTexts,
                translationFails: translationFails,
                storageFails: storageFails,
                finishFails: finishFails,
                modelLoadFails: modelLoadFails,
                recognitionFails: recognitionFails,
                recognitionError: recognitionError,
                recognitionDelay: recognitionDelay,
                recoveryStageFails: recoveryStageFails,
                recordingAppendFails: recordingAppendFails,
                recordingFinishFails: recordingFinishFails,
                recordingRepairFails: recordingRepairFails,
                modelPreparationDelay: modelPreparationDelay,
                audioFrames: audioFrames ?? [Self.audioFrame],
                holdsPermissionRequest: holdsPermissionRequest,
                holdsCaptureOpen: holdsCaptureOpen,
                emitsOnlyOnFlush: emitsOnlyOnFlush,
                emitsEveryFrame: emitsEveryFrame,
                translationMode: translationMode,
                sentenceVisibilityClock:
                    sentenceVisibilityClock ?? ContinuousSentenceVisibilityClock()
            ),
            sessionKind: sessionKind
        )
    }

    private init(
        components: SessionTestComponents,
        sessionKind: TranscriptSessionKind
    ) {
        let dependencies = SessionDependencyFactory.make(components)

        capture = components.capture
        processor = components.processor
        vad = components.vad
        asr = components.asr
        translator = components.translator
        downloader = components.downloader
        transcript = components.transcript
        store = components.store
        recordingStore = components.recordingStore
        recoveryStore = components.recoveryStore
        diagnostics = components.diagnostics
        coordinator = LiveSessionCoordinator(
            dependencies: dependencies,
            models: Self.models,
            sessionKind: sessionKind,
            sentenceVisibilityClock: components.sentenceVisibilityClock
        )
    }

    func run() async throws -> [LiveSessionEvent] {
        let stream = await coordinator.events()
        await coordinator.start(inputDeviceID: nil)
        return try await SessionEventWaiter.eventsUntilTerminal(from: stream)
    }

    static let audioFrame = AudioFrame(
        samples: Array(repeating: 0.25, count: 320),
        sampleRate: 16_000,
        channelCount: 1,
        timestamp: .zero
    )

    private static let models = SessionModelDescriptors(
        speechRecognition: descriptor(id: "asr", name: "Mandarin ASR"),
        translation: descriptor(id: "translation", name: "Hy-MT2")
    )

    private static func descriptor(id: String, name: String) -> ModelDescriptor {
        ModelDescriptor(
            id: ModelID(rawValue: id),
            displayName: name,
            version: "test",
            expectedBytes: 1,
            sha256: nil,
            license: "Apache-2.0"
        )
    }
}

func verifyRecognitionRequest(from harness: SessionTestHarness) async throws {
    let requests = await harness.asr.receivedRequests()
    let recognition = try #require(requests.first)
    #expect(requests.count == 1)
    #expect(recognition.segment.samples.count == 320)
    #expect(recognition.contextPrompt.contains("因着信"))
    #expect(recognition.contextPrompt.contains("称义"))
    #expect(recognition.contextPrompt.contains("恩典"))
    #expect(!recognition.contextPrompt.contains("我们"))
}

func verifyTranslationRequest(from harness: SessionTestHarness) async throws {
    let requests = await harness.translator.receivedRequests()
    let translation = try #require(requests.first)
    #expect(requests.count == 1)
    #expect(translation.context.isEmpty)
    #expect(
        translation.glossary == [
            TranslationTerm(source: "因信称义", target: "justification by faith"),
            TranslationTerm(source: "恩典", target: "grace"),
        ]
    )
}

func waitUntil(
    _ condition: @escaping @Sendable () async -> Bool
) async throws {
    for _ in 0..<100 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw SessionEventWaitError.timedOut
}
