import Accelerate
import Foundation

struct SmartTurnFourierTransform {
    private let realBasis: [Double]
    private let imaginaryBasis: [Double]
    private let window: [Double]

    init() {
        let frameLength = SmartTurnWhisperFeatureExtractor.frameLength
        let frequencyCount = SmartTurnWhisperFeatureExtractor.frequencyCount
        window = (0..<frameLength).map { index in
            0.5 - (0.5 * cos(2 * .pi * Double(index) / Double(frameLength)))
        }
        var real = [Double](repeating: 0, count: frameLength * frequencyCount)
        var imaginary = real
        for sampleIndex in 0..<frameLength {
            for frequencyIndex in 0..<frequencyCount {
                let angle =
                    2 * Double.pi * Double(sampleIndex * frequencyIndex)
                    / Double(frameLength)
                let offset = (sampleIndex * frequencyCount) + frequencyIndex
                real[offset] = cos(angle)
                imaginary[offset] = -sin(angle)
            }
        }
        realBasis = real
        imaginaryBasis = imaginary
    }

    func powerSpectrogram(of paddedAudio: [Double]) -> [Double] {
        let frames = windowedFrames(from: paddedAudio)
        let real = multiply(frames, by: realBasis)
        let imaginary = multiply(frames, by: imaginaryBasis)
        return zip(real, imaginary).map { realValue, imaginaryValue in
            let roundedReal = Double(Float(realValue))
            let roundedImaginary = Double(Float(imaginaryValue))
            return (roundedReal * roundedReal) + (roundedImaginary * roundedImaginary)
        }
    }

    private func windowedFrames(from audio: [Double]) -> [Double] {
        let frameCount = SmartTurnWhisperFeatureExtractor.frameCount
        let frameLength = SmartTurnWhisperFeatureExtractor.frameLength
        let hopLength = SmartTurnWhisperFeatureExtractor.hopLength
        var frames = [Double](repeating: 0, count: frameCount * frameLength)
        for frameIndex in 0..<frameCount {
            let sourceStart = frameIndex * hopLength
            let destinationStart = frameIndex * frameLength
            for sampleIndex in 0..<frameLength {
                frames[destinationStart + sampleIndex] =
                    audio[sourceStart + sampleIndex] * window[sampleIndex]
            }
        }
        return frames
    }

    private func multiply(_ frames: [Double], by basis: [Double]) -> [Double] {
        let frameCount = SmartTurnWhisperFeatureExtractor.frameCount
        let frameLength = SmartTurnWhisperFeatureExtractor.frameLength
        let frequencyCount = SmartTurnWhisperFeatureExtractor.frequencyCount
        var output = [Double](repeating: 0, count: frameCount * frequencyCount)
        vDSP_mmulD(
            frames,
            1,
            basis,
            1,
            &output,
            1,
            vDSP_Length(frameCount),
            vDSP_Length(frequencyCount),
            vDSP_Length(frameLength)
        )
        return output
    }
}
