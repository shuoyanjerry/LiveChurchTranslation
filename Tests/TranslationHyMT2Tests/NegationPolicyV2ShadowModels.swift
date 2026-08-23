struct NegationPolicyV2ShadowReport: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let manifestSHA256: String
    let classifiedReportSHA256: String
    let policySHA256: String
    let configurationSHA256: String
    let totalSegmentCount: Int
    let classifiedSuccessCount: Int
    let classifiedFailureCount: Int
    let allSegmentsSource: NegationPolicyV2ShadowAggregate
    let successfulAttemptsFull: NegationPolicyV2ShadowAggregate
    let failedAttemptsSource: NegationPolicyV2ShadowAggregate
    let acceptedUnsafeTargetUnicodeCount: Int
}

struct NegationPolicyV2ShadowAggregate: Codable, Equatable, Sendable {
    let totalCount: Int
    let dispositions: NegationPolicyV2ShadowDispositionCounts
    let overtCueRequirements: NegationPolicyV2ShadowOvertCueCounts
    let humanReviewReasons: NegationPolicyV2ShadowReviewReasonCounts
}

struct NegationPolicyV2ShadowDispositionCounts: Codable, Equatable, Sendable {
    var noFunctionalNegation = 0
    var requiresOvertCue = 0
    var humanReviewRequired = 0

    var total: Int {
        noFunctionalNegation + requiresOvertCue + humanReviewRequired
    }
}

struct NegationPolicyV2ShadowOvertCueCounts: Codable, Equatable, Sendable {
    var one = 0
    var two = 0
    var three = 0
    var fourOrMore = 0

    var total: Int { one + two + three + fourOrMore }
}

struct NegationPolicyV2ShadowReviewReasonCounts: Codable, Equatable, Sendable {
    var mixedPolarityClauses = 0
    var questionScope = 0
    var quantifierScope = 0
    var targetCueCountMismatch = 0
    var unexpectedTargetCue = 0
    var unclassifiedSourceCue = 0
    var unsafeSourceUnicode = 0
    var unsafeTargetUnicode = 0

    var total: Int {
        mixedPolarityClauses + questionScope + quantifierScope
            + targetCueCountMismatch + unexpectedTargetCue + unclassifiedSourceCue
            + unsafeSourceUnicode + unsafeTargetUnicode
    }
}

struct NegationPolicyV2ShadowDispositionSets: Sendable {
    let allSource: [NegationPolicyV2Disposition]
    let successfulFull: [NegationPolicyV2Disposition]
    let failedSource: [NegationPolicyV2Disposition]
}

enum NegationPolicyV2ShadowError: Error {
    case invalidConfiguration
    case invalidInput
    case invalidReport
    case privacyViolation
    case storageFailure
}
