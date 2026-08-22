import Testing
@testable import VADWebRTC

@Suite struct WebRTCVoiceActivityClassifierTests {
    @Test func sermonDefaultsMatchDeployedHybrid() {
        let value = WebRTCVoiceActivityConfiguration.sermon

        #expect(value.mode == .aggressive)
        #expect(value.initialNoiseFloorRMS == 0.0025)
        #expect(value.minimumEnergyRMS == 0.006)
        #expect(value.energyThresholdMultiplier == 3.2)
        #expect(value.strongEnergyRMS == 0.018)
        #expect(value.noiseFloorRetention == 0.995)
        #expect(WebRTCVADMode.allCases.map(\.rawValue) == [0, 1, 2, 3])
    }

    @Test func invalidFrameLengthIsTypedFailure() throws {
        let classifier = try WebRTCVoiceActivityClassifier()

        #expect(
            throws: WebRTCVoiceActivityClassifierError.invalidFrameLength(
                expected: 320,
                actual: 319
            )
        ) {
            try classifier.classify(Array(repeating: 0, count: 319), whileSpeaking: false)
        }
    }

    @Test func invalidEnergySettingIsTypedFailure() {
        #expect(
            throws: WebRTCVoiceActivityClassifierError.invalidConfiguration(
                parameter: "energyThresholdMultiplier"
            )
        ) {
            try WebRTCVoiceActivityClassifier(
                configuration: WebRTCVoiceActivityConfiguration(
                    energyThresholdMultiplier: 1
                )
            )
        }
    }

    @Test func nativeSilenceIsNotSpeech() throws {
        let classifier = try WebRTCVoiceActivityClassifier()

        #expect(!classifier.isSpeech(Array(repeating: 0, count: 320), whileSpeaking: false))
    }

    @Test func hybridAcceptsStrongAudio() throws {
        let classifier = try WebRTCVoiceActivityClassifier()
        let frame = Array(repeating: Float(0.1), count: 320)

        #expect(try classifier.classify(frame, whileSpeaking: false))
    }

    @Test func nonFiniteSamplesAreTypedFailure() throws {
        let classifier = try WebRTCVoiceActivityClassifier()
        var samples = Array(repeating: Float.zero, count: 320)
        samples[100] = .nan

        #expect(throws: WebRTCVoiceActivityClassifierError.nonFiniteSamples) {
            try classifier.classify(samples, whileSpeaking: false)
        }
    }

    @Test func resetRestoresNativeSilenceState() throws {
        let classifier = try WebRTCVoiceActivityClassifier()
        _ = try classifier.classify(Array(repeating: 0.1, count: 320), whileSpeaking: true)
        classifier.reset()

        #expect(try !classifier.classify(Array(repeating: 0, count: 320), whileSpeaking: false))
    }

    @Test func repeatedNativeLifetimesRemainIndependent() throws {
        for _ in 0..<100 {
            let classifier = try WebRTCVoiceActivityClassifier()
            #expect(!classifier.isSpeech(Array(repeating: 0, count: 320), whileSpeaking: false))
        }
    }
}
