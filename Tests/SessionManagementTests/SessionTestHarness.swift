import AudioCaptureAPI
import ASRNormalizationCore
import Foundation
import GlossaryAPI
import ModelRuntimeAPI
import SessionManagement
import SessionManagementAPI
import TranscriptCore

struct SessionTestHarness {
    let capture: FakeAudioCaptureProvider
    let processor: FakeAudioProcessor
    let vad: FakeSegmentingVAD
    let asr: FakeMandarinASRProvider
    let translator: FakeHyTranslationProvider
    let downloader: FakeModelDownloader
    let transcript: LiveTranscriptBuffer
    let store: FakeTranscriptStore
    let coordinator: LiveSessionCoordinator

    init(
        permission: AudioCapturePermission = .authorized,
        recognizedText: String = "我们因信称义，这是恩典。",
        translationFails: Bool = false,
        storageFails: Bool = false
    ) {
        let components = SessionTestComponents(
            permission: permission,
            recognizedText: recognizedText,
            translationFails: translationFails,
            storageFails: storageFails,
            audioFrame: Self.audioFrame
        )
        let dependencies = SessionDependencyFactory.make(components)

        capture = components.capture
        processor = components.processor
        vad = components.vad
        asr = components.asr
        translator = components.translator
        downloader = components.downloader
        transcript = components.transcript
        store = components.store
        coordinator = LiveSessionCoordinator(
            dependencies: dependencies,
            models: Self.models
        )
    }

    func run() async throws -> [LiveSessionEvent] {
        let stream = await coordinator.events()
        await coordinator.start(inputDeviceID: nil)
        return try await SessionEventWaiter.eventsUntilTerminal(from: stream)
    }

    private static let audioFrame = AudioFrame(
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
