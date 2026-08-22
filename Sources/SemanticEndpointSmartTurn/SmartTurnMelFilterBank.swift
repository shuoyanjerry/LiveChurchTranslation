import Foundation

struct SmartTurnMelFilterBank {
    let values: [Double]

    init() {
        let melCount = SmartTurnWhisperFeatureExtractor.melCount
        let frequencyCount = SmartTurnWhisperFeatureExtractor.frequencyCount
        let maximumMel = Self.hertzToMel(8_000)
        let melStep = maximumMel / Double(melCount + 1)
        let frequencies = (0..<(melCount + 2)).map { Self.melToHertz(Double($0) * melStep) }
        var filters = [Double](repeating: 0, count: frequencyCount * melCount)
        for frequencyIndex in 0..<frequencyCount {
            let hertz = Double(frequencyIndex) * 40
            for melIndex in 0..<melCount {
                let lower = frequencies[melIndex]
                let center = frequencies[melIndex + 1]
                let upper = frequencies[melIndex + 2]
                let downSlope = (hertz - lower) / (center - lower)
                let upSlope = (upper - hertz) / (upper - center)
                let areaScale = 2 / (upper - lower)
                filters[(frequencyIndex * melCount) + melIndex] =
                    max(0, min(downSlope, upSlope)) * areaScale
            }
        }
        values = filters
    }

    private static func hertzToMel(_ hertz: Double) -> Double {
        if hertz < 1_000 {
            return 3 * hertz / 200
        }
        return 15 + (log(hertz / 1_000) * 27 / log(6.4))
    }

    private static func melToHertz(_ mel: Double) -> Double {
        if mel < 15 {
            return 200 * mel / 3
        }
        return 1_000 * exp((log(6.4) / 27) * (mel - 15))
    }
}
