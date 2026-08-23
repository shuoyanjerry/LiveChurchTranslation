import Testing
import VADAPI
import VADWebRTC
@testable import VADCore

@MainActor
@Suite struct WebRTCCompatibilityTests {
    @Test func rejectsTenMillisecondConfigurationBeforeProcessing() throws {
        #expect(
            throws: WebRTCVoiceActivityClassifierError.invalidFrameLength(
                expected: 320,
                actual: 160
            )
        ) {
            try CalibratedVoiceActivityDetector(
                classifier: WebRTCVoiceActivityClassifier(),
                configuration: .init(analysisWindow: .milliseconds(10))
            )
        }
    }

    @Test func rejectsFortyEightKilohertzConfigurationBeforeProcessing() throws {
        #expect(
            throws: WebRTCVoiceActivityClassifierError.unsupportedSampleRate(
                expected: 16_000,
                actual: 48_000
            )
        ) {
            try CalibratedVoiceActivityDetector(
                classifier: WebRTCVoiceActivityClassifier(),
                configuration: .init(requiredSampleRate: 48_000)
            )
        }
    }
}
