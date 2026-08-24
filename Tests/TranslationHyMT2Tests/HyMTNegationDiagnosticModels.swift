import Foundation

enum HyMTNegationSourceCueClass: String, Codable, CaseIterable, Sendable {
    case specificPhrase
    case compoundBu
    case standaloneBu
    case embeddedBu
    case none
}

enum HyMTNegationTargetCueClass: String, Codable, CaseIterable, Sendable {
    case explicit
    case lexical
    case none
}

enum HyMTNegationDiagnosticIssueCode: String, Codable, CaseIterable, Sendable {
    case empty
    case implausibleLength
    case contextReplay
    case metaText
    case promptControl
    case sourceScript
    case missingTerm
    case missingNumber
    case missingNegation
    case scriptureReference
    case pronounProtocol
    case transportFailure
    case unexpectedValidationError
}

enum HyMTNegationDiagnosticAttemptPhase: String, Codable, CaseIterable, Sendable {
    case initial
    case strictRetry
}

struct HyMTNegationDiagnosticAttempt: Codable, Equatable, Sendable {
    let ordinal: Int
    let phase: HyMTNegationDiagnosticAttemptPhase
    let completionOutcome: String
    let targetCueClass: HyMTNegationTargetCueClass
    let validationIssueCodes: [HyMTNegationDiagnosticIssueCode]
    let latencySeconds: Double
    let outputAvailable: Bool
    let outputSHA256: String
}

struct HyMTNegationDiagnosticEntry: Codable, Equatable, Sendable {
    let segmentID: String
    let sourceID: String
    let sequence: Int
    let classifiedFailureCode: String
    let sourceCueClasses: [HyMTNegationSourceCueClass]
    let referenceCueClass: HyMTNegationTargetCueClass
    let attemptCount: Int
    let totalLatencySeconds: Double
    let terminalFailureCode: String
    let attempts: [HyMTNegationDiagnosticAttempt]
}

struct HyMTNegationDiagnosticReport: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let manifestSHA256: String
    let classifiedReportSHA256: String
    let modelSHA256: String
    let entries: [HyMTNegationDiagnosticEntry]
}

struct HyMTNegationCompletionObservation: Sendable {
    let output: String?
    let latencySeconds: Double
}

struct HyMTNegationDiagnosticRunResult: Sendable {
    let report: HyMTNegationDiagnosticReport
    let protectedModelOutputs: [String]
}

struct HyMTNegationDiagnosticSegmentResult: Sendable {
    let entry: HyMTNegationDiagnosticEntry
    let protectedModelOutputs: [String]
}
