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
            let pages = try await dependencies.recoveryStore.recoverAllPendingPages(
                maximumRecordsPerPage: recoveryPageSize
            )
            return await replay(pages)
        } catch {
            return [issue(message: error.localizedDescription)]
        }
    }

    private func replay(_ pages: UtteranceRecoveryPages) async -> [LiveSessionIssue] {
        var issues: [LiveSessionIssue] = []
        var cursor: RecoverySessionCursor?
        do {
            for try await page in pages {
                issues += quarantineIssues(page.quarantined)
                for record in page.pending {
                    await replay(record, cursor: &cursor, issues: &issues)
                }
            }
        } catch {
            issues += await close(&cursor)
            issues.append(issue(message: error.localizedDescription))
        }
        issues += await close(&cursor)
        return issues
    }

    private func replay(
        _ record: PendingUtteranceRecord,
        cursor: inout RecoverySessionCursor?,
        issues: inout [LiveSessionIssue]
    ) async {
        guard record.id.sessionID != excludedSessionID else { return }
        if cursor?.id != record.id.sessionID {
            issues += await close(&cursor)
            cursor = await makeCursor(sessionID: record.id.sessionID)
        }
        guard var active = cursor else { return }
        await replay(record, cursor: &active)
        cursor = active
    }

    private func close(
        _ cursor: inout RecoverySessionCursor?
    ) async -> [LiveSessionIssue] {
        guard let active = cursor else { return [] }
        cursor = nil
        return await finalize(active)
    }

    private var recoveryPageSize: Int { 4 }

    private func quarantineIssues(
        _ artifacts: [QuarantinedUtterance]
    ) -> [LiveSessionIssue] {
        artifacts.map {
            issue(message: "A pending sentence was quarantined: \($0.reason.rawValue).")
        }
    }

    func issue(
        stage: LiveSessionIssueStage = .persistence,
        sequence: UInt64? = nil,
        message: String
    ) -> LiveSessionIssue {
        LiveSessionIssue(
            stage: stage,
            utteranceSequence: sequence,
            message: message,
            isRecoverable: true
        )
    }
}
