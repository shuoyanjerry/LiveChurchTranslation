struct InterleavedDownmixer {
    func mix(
        samples: [Float],
        channelCount: Int,
        amplitudeLimit: Float
    ) -> [Float] {
        guard channelCount > 1 else {
            return samples.map { clamp($0, limit: amplitudeLimit) }
        }

        let frameCount = samples.count / channelCount
        return (0..<frameCount).map { frameIndex in
            let offset = frameIndex * channelCount
            let sum = samples[offset..<(offset + channelCount)].reduce(0, +)
            return clamp(sum / Float(channelCount), limit: amplitudeLimit)
        }
    }

    private func clamp(_ sample: Float, limit: Float) -> Float {
        min(max(sample, -limit), limit)
    }
}
