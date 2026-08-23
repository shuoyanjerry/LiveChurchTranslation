/// Fail-closed Report V3 construction failures.
public enum ASRQualificationReportV3Error: Error, Equatable, Sendable {
    case invalidManifest(ASRQualificationError)
    case invalidGeneratedAt
    case invalidQualificationManifestSHA256
    case invalidProviderField(String)
    case invalidProviderLane(String)
    case invalidEnvironmentField(String)
    case invalidSettingKey(String)
    case invalidSettingValue(String)
    case duplicateClipID(String)
    case clipSetMismatch(expected: [String], actual: [String])
    case segmentDefinitionsMismatch(clipID: String)
    case invalidSourceAudioSeconds(clipID: String)
    case sourceAudioSecondsMismatch(clipID: String)
    case referenceSHA256Mismatch(clipID: String, expected: String, actual: String)
    case attemptCountMismatch(clipID: String, expected: Int, actual: Int)
    case attemptSequenceMismatch(clipID: String, expected: Int, actual: Int)
    case attemptInputSampleCountMismatch(
        clipID: String,
        sequence: Int,
        expected: Int,
        actual: Int
    )
    case attemptPCMHashMismatch(
        clipID: String,
        sequence: Int,
        expected: String,
        actual: String
    )
    case invalidElapsedSeconds(clipID: String, sequence: Int)
    case successfulAttemptMissingHypothesis(clipID: String, sequence: Int)
    case successfulAttemptHasFailureCode(clipID: String, sequence: Int)
    case failedAttemptHasHypothesis(clipID: String, sequence: Int)
    case failedAttemptMissingFailureCode(clipID: String, sequence: Int)
    case numericOverflow(String)
    case nonFiniteAggregate(String)
}
