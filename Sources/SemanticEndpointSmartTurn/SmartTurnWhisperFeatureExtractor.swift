import Accelerate
import Foundation

struct SmartTurnWhisperFeatureExtractor {
    static let sampleCount = 128_000
    static let frameLength = 400
    static let hopLength = 160
    static let frameCount = 800
    static let frequencyCount = 201
    static let melCount = 80

    private let fourierTransform = SmartTurnFourierTransform()
    private let melFilters = SmartTurnMelFilterBank().values

    func extract(_ samples: [Float]) throws -> [Float] {
        try Task.checkCancellation()
        let paddedAudio = SmartTurnAudioPreparation.normalizeAndCenterPad(samples)
        try Task.checkCancellation()
        let power = fourierTransform.powerSpectrogram(of: paddedAudio)
        try Task.checkCancellation()
        let timeMajorMel = applyMelFilters(to: power)
        return logMelFeatures(from: timeMajorMel)
    }

    private func applyMelFilters(to power: [Double]) -> [Double] {
        var output = [Double](repeating: 0, count: Self.frameCount * Self.melCount)
        vDSP_mmulD(
            power,
            1,
            melFilters,
            1,
            &output,
            1,
            vDSP_Length(Self.frameCount),
            vDSP_Length(Self.melCount),
            vDSP_Length(Self.frequencyCount)
        )
        return output
    }

    private func logMelFeatures(from timeMajorMel: [Double]) -> [Float] {
        let logMel = timeMajorMel.map { log10(max(1e-10, $0)) }
        let maximum = logMel.max() ?? -10
        var features = [Float](repeating: 0, count: Self.frameCount * Self.melCount)
        for melIndex in 0..<Self.melCount {
            for frameIndex in 0..<Self.frameCount {
                let value = logMel[(frameIndex * Self.melCount) + melIndex]
                features[(melIndex * Self.frameCount) + frameIndex] =
                    Float((max(value, maximum - 8) + 4) / 4)
            }
        }
        return features
    }
}
