import Foundation

/// Loads exact absolute ranges from one source WAV and verifies every identity boundary.
public struct ASRQualificationWAVLoader: Sendable {
    public init() {}

    public func load(
        clip: ASRQualificationClipV2,
        from sourceWAVURL: URL
    ) throws -> [ASRQualificationLoadedSegment] {
        try ASRQualificationManifestRules.validate(clip)
        let source = try QualificationWAVFile(contentsOf: sourceWAVURL)
        try validate(source, for: clip)
        return try clip.segments.map { segment in
            try load(segment, of: clip, from: source)
        }
    }

    private func validate(
        _ source: QualificationWAVFile,
        for clip: ASRQualificationClipV2
    ) throws {
        guard source.rawSHA256 == clip.audioSHA256 else {
            throw ASRQualificationError.audioSHA256Mismatch(
                clipID: clip.id,
                expected: clip.audioSHA256,
                actual: source.rawSHA256
            )
        }
        guard source.sampleRate == clip.sampleRate else {
            throw ASRQualificationError.sampleRateMismatch(
                clipID: clip.id,
                expected: clip.sampleRate,
                actual: source.sampleRate
            )
        }
        guard source.totalSamples == clip.totalSamples else {
            throw ASRQualificationError.totalSamplesMismatch(
                clipID: clip.id,
                expected: clip.totalSamples,
                actual: source.totalSamples
            )
        }
    }

    private func load(
        _ segment: ASRQualificationSegmentV2,
        of clip: ASRQualificationClipV2,
        from source: QualificationWAVFile
    ) throws -> ASRQualificationLoadedSegment {
        var samples: [Float]
        do {
            samples = try source.samples(
                start: segment.startSample,
                count: segment.validSampleCount
            )
        } catch let error as QualificationWAVReadError {
            switch error {
            case .nonFiniteSample(let sourceSample):
                throw ASRQualificationError.nonFiniteFloatSample(
                    clipID: clip.id,
                    sequence: segment.sequence,
                    sourceSample: sourceSample
                )
            }
        } catch {
            throw ASRQualificationError.segmentReadFailed(
                clipID: clip.id,
                sequence: segment.sequence
            )
        }
        samples.append(
            contentsOf: repeatElement(0, count: segment.syntheticPaddingSamples)
        )
        try validateFinite(samples, segment: segment, clipID: clip.id)
        let actualHash = QualificationSHA256.pcm(samples)
        guard actualHash == segment.pcmSHA256 else {
            throw ASRQualificationError.pcmSHA256Mismatch(
                clipID: clip.id,
                sequence: segment.sequence,
                expected: segment.pcmSHA256,
                actual: actualHash
            )
        }
        return ASRQualificationLoadedSegment(definition: segment, samples: samples)
    }

    private func validateFinite(
        _ samples: [Float],
        segment: ASRQualificationSegmentV2,
        clipID: String
    ) throws {
        guard let offset = samples.firstIndex(where: { !$0.isFinite }) else { return }
        throw ASRQualificationError.nonFiniteFloatSample(
            clipID: clipID,
            sequence: segment.sequence,
            sourceSample: segment.startSample + offset
        )
    }
}
