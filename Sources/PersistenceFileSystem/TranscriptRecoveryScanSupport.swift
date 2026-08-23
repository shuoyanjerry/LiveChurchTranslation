import Foundation
import PersistenceAPI

final class TranscriptRecoveryIssueCollector {
    private(set) var issues: [TranscriptRecoveryScanIssue] = []

    func append(_ issue: TranscriptRecoveryScanIssue?) {
        if let issue { issues.append(issue) }
    }

    func appendEnumerationFailure(url: URL, error: any Error) {
        issues.append(
            TranscriptRecoveryScanIssue(
                code: .enumerationFailed,
                sessionID: UUID(uuidString: url.lastPathComponent),
                message: "扫描一项听抄稿资料时失败，已跳过该项。",
                technicalDetail: error.localizedDescription
            )
        )
    }
}

struct TranscriptRecoveryItemInspection {
    static let skipped = TranscriptRecoveryItemInspection()

    let candidate: TranscriptRecoveryCandidate?
    let issue: TranscriptRecoveryScanIssue?

    init(
        candidate: TranscriptRecoveryCandidate? = nil,
        issue: TranscriptRecoveryScanIssue? = nil
    ) {
        self.candidate = candidate
        self.issue = issue
    }
}

struct TranscriptRecoveryScanState {
    let candidateLimit: Int
    let maximumDirectoryEntries: Int
    private(set) var candidates: [TranscriptRecoveryCandidate] = []
    private(set) var visitedCount = 0
    private(set) var didReachLimit: Bool

    init(requestedCount: Int, limits: TranscriptRecoveryLimits) {
        candidateLimit = min(requestedCount, limits.maximumCandidateSessions)
        maximumDirectoryEntries = limits.maximumDirectoryEntries
        didReachLimit = requestedCount > limits.maximumCandidateSessions
    }

    mutating func beginVisit() -> Bool {
        guard visitedCount < maximumDirectoryEntries else {
            didReachLimit = true
            return false
        }
        visitedCount += 1
        return true
    }

    mutating func append(_ candidate: TranscriptRecoveryCandidate?) -> Bool {
        guard let candidate else { return true }
        guard candidates.count < candidateLimit else {
            didReachLimit = true
            return false
        }
        candidates.append(candidate)
        return true
    }

    func result(issues: [TranscriptRecoveryScanIssue]) -> TranscriptRecoveryScan {
        TranscriptRecoveryScan(
            candidates: candidates,
            issues: issues,
            didReachLimit: didReachLimit
        )
    }
}
