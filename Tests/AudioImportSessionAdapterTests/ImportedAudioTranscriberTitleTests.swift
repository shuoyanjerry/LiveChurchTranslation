import AudioCaptureAPI
import AudioImportSessionAdapter
import Foundation
import SettingsAPI
import Testing

@Suite @MainActor struct ImportedAudioTranscriberTitleTests {
    @Test func requestedSessionTitleReachesControllerFactory() async {
        var receivedTitle: String?
        let transcriber = ImportedAudioTranscriber(
            inputDeviceID: AudioInputID(rawValue: "import-test")
        ) { _, _, title in
            receivedTitle = title
            throw TitleTestError.factoryFailed
        }

        await #expect(throws: TitleTestError.factoryFailed) {
            try await transcriber.importAudio(
                from: URL(fileURLWithPath: "/tmp/import.wav"),
                mode: .mandarinToEnglish,
                sessionTitle: "主日信息（重新听抄）"
            )
        }
        #expect(receivedTitle == "主日信息（重新听抄）")
    }
}

private enum TitleTestError: Error {
    case factoryFailed
}
