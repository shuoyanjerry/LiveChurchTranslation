import ASRQualificationSupport
import Foundation

extension ManifestToolBuilder {
    func makeClip(
        file: VADFile,
        corpusClip: CorpusClip,
        referenceClip: ReferenceClip,
        requiredSampleRate: Int
    ) throws -> ASRQualificationClipV2 {
        let id = try ManifestToolConsistency.clipID(fileName: file.fileName)
        try validateFile(file, id: id, requiredSampleRate: requiredSampleRate)
        guard
            URL(fileURLWithPath: corpusClip.audioPath).deletingPathExtension()
                .lastPathComponent == id
        else {
            throw ManifestToolError.invalidValue(path: "corpus.\(id).audio_path")
        }
        let segments = try file.boundaries.enumerated().map { index, boundary in
            try makeSegment(boundary, expectedSequence: index + 1, clipID: id)
        }
        return ASRQualificationClipV2(
            id: id,
            audioSHA256: file.sha256,
            sampleRate: file.sampleRateHz,
            totalSamples: file.totalSamples,
            referenceSHA256: ManifestToolHashing.referenceText(corpusClip.referenceText),
            allowsHypothesisEdgeInsertions: referenceClip.ignoresHypothesisEdges,
            segments: segments
        )
    }

    private func validateFile(
        _ file: VADFile,
        id: String,
        requiredSampleRate: Int
    ) throws {
        guard !file.corpusID.allSatisfy(\.isWhitespace),
            file.byteCount > 0,
            file.sampleRateHz == requiredSampleRate,
            file.totalSamples > 0,
            file.audioSeconds.isFinite,
            file.audioSeconds > 0,
            file.metrics.segmentCount == file.boundaries.count
        else {
            throw ManifestToolError.invalidVADFile(id)
        }
        let expectedSeconds = Double(file.totalSamples) / Double(file.sampleRateHz)
        guard abs(file.audioSeconds - expectedSeconds) <= 1e-9 else {
            throw ManifestToolError.invalidVADFile(id)
        }
    }

    private func makeSegment(
        _ boundary: VADBoundary,
        expectedSequence: Int,
        clipID: String
    ) throws -> ASRQualificationSegmentV2 {
        guard let sequence = Int(exactly: boundary.sequenceNumber),
            sequence == expectedSequence,
            boundary.syntheticPaddingSamplesAtEmission == 0,
            validTiming(boundary)
        else {
            throw ManifestToolError.invalidBoundary(
                clipID: clipID,
                sequence: expectedSequence
            )
        }
        return ASRQualificationSegmentV2(
            sequence: sequence,
            startSample: boundary.startSample,
            endSample: boundary.endSample,
            validSampleCount: boundary.validSampleCount,
            syntheticPaddingSamples: 0,
            endReason: boundary.reason,
            pcmSHA256: boundary.pcmSHA256
        )
    }

    private func validTiming(_ boundary: VADBoundary) -> Bool {
        let allowedReasons = [
            "trailingSilence", "softSilence", "maximumBoundary",
            "maximumDuration", "endOfStream",
        ]
        return boundary.startedAtSeconds.isFinite
            && boundary.endedAtSeconds.isFinite
            && boundary.durationSeconds.isFinite
            && boundary.signedEmissionOffsetSeconds.isFinite
            && boundary.emissionLagAfterRetainedAudioSeconds?.isFinite != false
            && allowedReasons.contains(boundary.reason)
    }
}
