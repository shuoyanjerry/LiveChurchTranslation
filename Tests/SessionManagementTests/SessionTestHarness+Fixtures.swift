import AudioCaptureAPI
import ModelRuntimeAPI
@testable import SessionManagement
import SessionManagementAPI

extension SessionTestHarness {
    static let audioFrame = AudioFrame(
        samples: Array(repeating: 0.25, count: 320),
        sampleRate: 16_000,
        channelCount: 1,
        timestamp: .zero
    )

    static let models = SessionModelDescriptors(
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
