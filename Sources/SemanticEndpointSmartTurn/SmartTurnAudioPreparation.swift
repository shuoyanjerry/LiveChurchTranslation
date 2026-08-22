import Foundation

enum SmartTurnAudioPreparation {
    static func normalizeAndCenterPad(_ input: [Float]) -> [Double] {
        var turn = lastEightSeconds(input)
        let mean = numpyPairwiseSum(turn, in: turn.indices) / Float(turn.count)
        var centered = [Float](repeating: 0, count: turn.count)
        var squares = centered
        for index in turn.indices {
            centered[index] = turn[index] - mean
            squares[index] = centered[index] * centered[index]
        }
        let variance = numpyPairwiseSum(squares, in: squares.indices) / Float(squares.count)
        let deviation = sqrt(variance + 1e-7)
        for index in turn.indices {
            turn[index] = centered[index] / deviation
        }
        return reflectPad(turn)
    }

    private static func numpyPairwiseSum(_ values: [Float], in range: Range<Int>) -> Float {
        let count = range.count
        if count < 8 {
            return range.reduce(-Float.zero) { $0 + values[$1] }
        }
        if count <= 128 {
            var partials = (0..<8).map { values[range.lowerBound + $0] }
            let groupedEnd = range.lowerBound + (count - (count % 8))
            var index = range.lowerBound + 8
            while index < groupedEnd {
                for lane in 0..<8 {
                    partials[lane] += values[index + lane]
                }
                index += 8
            }
            var result =
                ((partials[0] + partials[1]) + (partials[2] + partials[3]))
                + ((partials[4] + partials[5]) + (partials[6] + partials[7]))
            while index < range.upperBound {
                result += values[index]
                index += 1
            }
            return result
        }
        var midpoint = count / 2
        midpoint -= midpoint % 8
        let split = range.lowerBound + midpoint
        return numpyPairwiseSum(values, in: range.lowerBound..<split)
            + numpyPairwiseSum(values, in: split..<range.upperBound)
    }

    private static func lastEightSeconds(_ input: [Float]) -> [Float] {
        let expectedCount = SmartTurnWhisperFeatureExtractor.sampleCount
        if input.count >= expectedCount {
            return Array(input.suffix(expectedCount))
        }
        return [Float](repeating: 0, count: expectedCount - input.count) + input
    }

    private static func reflectPad(_ input: [Float]) -> [Double] {
        let pad = SmartTurnWhisperFeatureExtractor.frameLength / 2
        var result = [Double](repeating: 0, count: input.count + (2 * pad))
        for index in 0..<pad {
            result[index] = Double(input[pad - index])
            result[pad + input.count + index] = Double(input[input.count - 2 - index])
        }
        for index in input.indices {
            result[pad + index] = Double(input[index])
        }
        return result
    }
}
