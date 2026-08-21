import VADAPI

struct AdaptiveEnergyClassifier {
    private let configuration: VoiceActivityConfiguration
    private(set) var noiseFloorRMS: Float

    init(configuration: VoiceActivityConfiguration) {
        self.configuration = configuration
        noiseFloorRMS = configuration.initialNoiseFloorRMS
    }

    mutating func isSpeech(_ samples: [Float], whileSpeaking: Bool) -> Bool {
        let energy = rootMeanSquare(of: samples)
        let threshold = max(
            configuration.minimumSpeechRMS,
            noiseFloorRMS * configuration.speechThresholdMultiplier
        )
        let detected = energy >= threshold
        if !whileSpeaking, !detected {
            adaptNoiseFloor(toward: energy)
        }
        return detected
    }

    mutating func reset() {
        noiseFloorRMS = configuration.initialNoiseFloorRMS
    }

    private func rootMeanSquare(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let squareSum = samples.reduce(into: 0.0) { result, sample in
            let value = Double(sample)
            result += value * value
        }
        return Float((squareSum / Double(samples.count)).squareRoot())
    }

    private mutating func adaptNoiseFloor(toward energy: Float) {
        let retained = configuration.noiseFloorSmoothing * noiseFloorRMS
        let observed = (1 - configuration.noiseFloorSmoothing) * energy
        noiseFloorRMS = retained + observed
    }
}
