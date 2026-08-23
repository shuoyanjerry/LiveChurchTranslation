/// Verified Float32 PCM ready to pass to an ASR provider without further slicing.
public struct ASRQualificationLoadedSegment: Equatable, Sendable {
    public let definition: ASRQualificationSegmentV2
    public let samples: [Float]

    public init(
        definition: ASRQualificationSegmentV2,
        samples: [Float]
    ) {
        self.definition = definition
        self.samples = samples
    }
}
