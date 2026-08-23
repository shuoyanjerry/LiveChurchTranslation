/// Fail-closed decoding, manifest, source-audio, and PCM verification failures.
public enum ASRQualificationError: Error, Equatable, Sendable {
    case manifestReadFailed(String)
    case malformedManifest
    case duplicateJSONField(path: String, field: String)
    case unexpectedField(path: String, field: String)
    case unsupportedSchemaVersion(Int)
    case emptyCorpusID
    case emptyProvenanceField(String)
    case emptyClips
    case invalidClipID(index: Int)
    case duplicateClipID(String)
    case invalidSampleRate(clipID: String, value: Int)
    case invalidTotalSamples(clipID: String, value: Int)
    case invalidSHA256(path: String)
    case emptySegments(clipID: String)
    case invalidSequence(clipID: String, expected: Int, actual: Int)
    case nonIncreasingSegmentOrder(clipID: String, sequence: Int)
    case invalidSegmentRange(clipID: String, sequence: Int)
    case invalidSampleAccounting(clipID: String, sequence: Int)
    case syntheticPaddingLimitExceeded(
        clipID: String,
        sequence: Int,
        value: Int,
        maximum: Int
    )
    case loadedSampleLimitExceeded(
        clipID: String,
        sequence: Int,
        value: Int,
        maximum: Int
    )
    case loadedClipSampleLimitExceeded(clipID: String, maximum: Int)
    case emptyEndReason(clipID: String, sequence: Int)
    case audioReadFailed(String)
    case unsupportedWAV(String)
    case audioSHA256Mismatch(clipID: String, expected: String, actual: String)
    case sampleRateMismatch(clipID: String, expected: Int, actual: Int)
    case totalSamplesMismatch(clipID: String, expected: Int, actual: Int)
    case segmentReadFailed(clipID: String, sequence: Int)
    case nonFiniteFloatSample(clipID: String, sequence: Int, sourceSample: Int)
    case pcmSHA256Mismatch(
        clipID: String,
        sequence: Int,
        expected: String,
        actual: String
    )
}
