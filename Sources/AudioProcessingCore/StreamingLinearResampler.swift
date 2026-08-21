/// Linear resampling state whose phase is continuous across capture buffers.
struct StreamingLinearResampler {
    private var bufferedSamples: [Float] = []
    private var nextSourcePosition = 0.0

    mutating func convert(
        _ input: [Float],
        sourceRate: Double,
        targetRate: Double
    ) -> [Float] {
        guard sourceRate != targetRate else { return input }

        bufferedSamples.append(contentsOf: input)
        let step = sourceRate / targetRate
        var output: [Float] = []
        output.reserveCapacity(estimatedOutputCount(step: step))

        while nextSourcePosition + 1 < Double(bufferedSamples.count) {
            let lowerIndex = Int(nextSourcePosition)
            let fraction = Float(nextSourcePosition - Double(lowerIndex))
            let lower = bufferedSamples[lowerIndex]
            let upper = bufferedSamples[lowerIndex + 1]
            output.append(lower + ((upper - lower) * fraction))
            nextSourcePosition += step
        }

        discardConsumedSamples()
        return output
    }

    mutating func reset() {
        bufferedSamples.removeAll(keepingCapacity: true)
        nextSourcePosition = 0
    }

    private func estimatedOutputCount(step: Double) -> Int {
        guard step > 0 else { return 0 }
        let remaining = max(0, Double(bufferedSamples.count) - nextSourcePosition)
        return Int((remaining / step).rounded(.up))
    }

    private mutating func discardConsumedSamples() {
        let count = min(Int(nextSourcePosition.rounded(.down)), bufferedSamples.count)
        guard count > 0 else { return }
        bufferedSamples.removeFirst(count)
        nextSourcePosition -= Double(count)
    }
}
