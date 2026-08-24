import Foundation
import DiscourseResolutionAPI
import SessionManagementAPI
import TranscriptAPI
import TranslationAPI
import UtteranceRecoveryAPI

struct UtteranceRecoveryReplayer: Sendable {
    let dependencies: LiveSessionDependencies
    let processor: UtteranceProcessor
    let excludedSessionID: UUID?

    func replay() async -> [LiveSessionIssue] {
        do {
            try Task.checkCancellation()
            let pages = try await dependencies.recoveryStore.recoverAllPendingPages(
                maximumRecordsPerPage: recoveryPageSize
            )
            return await replay(pages)
        } catch is CancellationError {
            return []
        } catch {
            return [issue(message: error.localizedDescription)]
        }
    }

    private func replay(_ pages: UtteranceRecoveryPages) async -> [LiveSessionIssue] {
        var issues = BoundedLiveSessionIssueBuffer()
        var cursor: RecoverySessionCursor?
        do {
            try await scan(pages, cursor: &cursor, issues: &issues)
        } catch is CancellationError {
            cursor?.isBlocked = true
        } catch {
            cursor?.isBlocked = true
            issues.append(issue(message: error.localizedDescription))
        }
        let closeResult = await close(&cursor)
        issues.append(contentsOf: closeResult.issues)
        return issues.values
    }

    private func scan(
        _ pages: UtteranceRecoveryPages,
        cursor: inout RecoverySessionCursor?,
        issues: inout BoundedLiveSessionIssueBuffer
    ) async throws {
        for try await page in pages {
            try Task.checkCancellation()
            issues.append(contentsOf: quarantineIssues(page.quarantined))
            for record in page.pending {
                try Task.checkCancellation()
                let transition = await replay(record, cursor: &cursor)
                issues.append(contentsOf: transition.issues)
                guard !transition.isBlocked, cursor?.isBlocked != true else { return }
            }
        }
    }

    private func replay(
        _ record: PendingUtteranceRecord,
        cursor: inout RecoverySessionCursor?
    ) async -> RecoveryCursorCloseResult {
        guard record.id.sessionID != excludedSessionID else { return .closedWithoutIssue }
        var closeResult = RecoveryCursorCloseResult.closedWithoutIssue
        if cursor?.id != record.id.sessionID {
            closeResult = await close(&cursor)
            guard !closeResult.isBlocked else { return closeResult }
            cursor = await makeCursor(sessionID: record.id.sessionID)
        }
        guard var active = cursor else { return closeResult }
        await replay(record, cursor: &active)
        cursor = active
        return closeResult
    }

    private func close(
        _ cursor: inout RecoverySessionCursor?
    ) async -> RecoveryCursorCloseResult {
        guard let active = cursor else { return .closedWithoutIssue }
        cursor = nil
        return await finalize(active)
    }

    private var recoveryPageSize: Int { 4 }

    private func quarantineIssues(
        _ artifacts: [QuarantinedUtterance]
    ) -> [LiveSessionIssue] {
        artifacts.map { _ in issue(message: "一条待处理片段损坏，已安全隔离。") }
    }

    func issue(
        stage: LiveSessionIssueStage = .persistence,
        sequence: UInt64? = nil,
        message: String,
        isRecoverable: Bool = true
    ) -> LiveSessionIssue {
        LiveSessionIssue(
            stage: stage,
            utteranceSequence: sequence,
            message: message,
            isRecoverable: isRecoverable
        )
    }
}
