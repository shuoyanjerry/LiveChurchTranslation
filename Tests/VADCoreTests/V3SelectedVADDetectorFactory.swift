import VADAPI
import VADCore
import VADWebRTC

enum V3SelectedVADDetectorFactory {
    static func make() throws -> CalibratedVoiceActivityDetector {
        try CalibratedVoiceActivityDetector(
            classifier: try WebRTCVoiceActivityClassifier(configuration: .sermon),
            configuration: .sermon
        )
    }
}
