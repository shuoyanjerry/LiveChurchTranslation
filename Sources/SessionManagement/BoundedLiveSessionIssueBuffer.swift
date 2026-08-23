import SessionManagementAPI

struct BoundedLiveSessionIssueBuffer: Sendable {
    static let maximumRetainedCount = 32

    private var retained: [LiveSessionIssue] = []
    private var suppressedCount = 0
    private var suppressedRecoverableIssue = false

    var values: [LiveSessionIssue] {
        guard suppressedCount > 0 else { return retained }
        return retained + [
            LiveSessionIssue(
                stage: .finalization,
                message: "另有 \(suppressedCount) 条处理问题已折叠显示。",
                isRecoverable: suppressedRecoverableIssue
            )
        ]
    }

    mutating func append(_ issue: LiveSessionIssue) {
        guard
            suppressedCount > 0
                || retained.count == Self.maximumRetainedCount
        else {
            retained.append(issue)
            return
        }

        let targetCount = Self.maximumRetainedCount - 1
        while retained.count >= targetCount {
            let removalIndex = retained.count > 1 ? 1 : 0
            let removed = retained.remove(at: removalIndex)
            suppressedCount += 1
            suppressedRecoverableIssue = suppressedRecoverableIssue || removed.isRecoverable
        }
        retained.append(issue)
    }

    mutating func append(contentsOf issues: [LiveSessionIssue]) {
        issues.forEach { append($0) }
    }
}
