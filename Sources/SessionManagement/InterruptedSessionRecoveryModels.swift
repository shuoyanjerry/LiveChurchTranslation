import Foundation

public struct InterruptedSessionRecoveryIssue: Equatable, Sendable {
    public enum Stage: String, Equatable, Sendable {
        case scan
        case recording
        case transcript
    }

    public enum Code: String, Equatable, Sendable {
        case scanFailed = "startup_recovery.scan_failed"
        case traversalLimitReached = "startup_recovery.traversal_limit_reached"
        case recordingRepairFailed = "startup_recovery.recording_repair_failed"
        case transcriptRepairFailed = "startup_recovery.transcript_repair_failed"
    }

    public let code: Code
    public let stage: Stage
    public let sessionID: UUID?
    public let message: String
    public let technicalDetail: String?

    public init(
        code: Code,
        stage: Stage,
        sessionID: UUID?,
        message: String,
        technicalDetail: String? = nil
    ) {
        self.code = code
        self.stage = stage
        self.sessionID = sessionID
        self.message = message
        self.technicalDetail = technicalDetail
    }
}

public struct InterruptedSessionRecoveryReport: Equatable, Sendable {
    public let candidateCount: Int
    public let repairedRecordingCount: Int
    public let recoveredTranscriptCount: Int
    public let skippedActiveCount: Int
    public let didReachLimit: Bool
    public let issues: [InterruptedSessionRecoveryIssue]

    public init(
        candidateCount: Int,
        repairedRecordingCount: Int,
        recoveredTranscriptCount: Int,
        skippedActiveCount: Int,
        didReachLimit: Bool,
        issues: [InterruptedSessionRecoveryIssue]
    ) {
        self.candidateCount = candidateCount
        self.repairedRecordingCount = repairedRecordingCount
        self.recoveredTranscriptCount = recoveredTranscriptCount
        self.skippedActiveCount = skippedActiveCount
        self.didReachLimit = didReachLimit
        self.issues = issues
    }
}

struct InterruptedRecoveryOutcome: Sendable {
    var repairedRecordingCount: Int
    var recoveredTranscriptCount: Int
    var skippedActiveCount: Int
    var issues: [InterruptedSessionRecoveryIssue]

    init(
        repairedRecordingCount: Int = 0,
        recoveredTranscriptCount: Int = 0,
        skippedActiveCount: Int = 0,
        issues: [InterruptedSessionRecoveryIssue] = []
    ) {
        self.repairedRecordingCount = repairedRecordingCount
        self.recoveredTranscriptCount = recoveredTranscriptCount
        self.skippedActiveCount = skippedActiveCount
        self.issues = issues
    }

    mutating func merge(_ other: Self) {
        repairedRecordingCount += other.repairedRecordingCount
        recoveredTranscriptCount += other.recoveredTranscriptCount
        skippedActiveCount += other.skippedActiveCount
        issues.append(contentsOf: other.issues)
    }

    func report(
        candidateCount: Int,
        didReachLimit: Bool
    ) -> InterruptedSessionRecoveryReport {
        InterruptedSessionRecoveryReport(
            candidateCount: candidateCount,
            repairedRecordingCount: repairedRecordingCount,
            recoveredTranscriptCount: recoveredTranscriptCount,
            skippedActiveCount: skippedActiveCount,
            didReachLimit: didReachLimit,
            issues: issues
        )
    }
}
