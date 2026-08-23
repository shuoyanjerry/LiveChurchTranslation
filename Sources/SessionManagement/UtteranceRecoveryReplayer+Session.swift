import Foundation
import SessionManagementAPI
import SettingsAPI
import TranscriptAPI
import TranslationAPI
import UtteranceRecoveryAPI

struct RecoverySessionCursor {
    let id: UUID
    let stored: TranscriptSession?
    var entries: [TranscriptEntry]
    let unavailableMessage: String?
    var issues = BoundedLiveSessionIssueBuffer()
    var isBlocked = false
    var terminalRejectionCount = 0
}

extension UtteranceRecoveryReplayer {
    func makeCursor(sessionID: UUID) async -> RecoverySessionCursor {
        do {
            guard let stored = try await dependencies.transcriptStore.load(sessionID: sessionID)
            else {
                return unavailableCursor(id: sessionID, message: "找不到对应的听抄稿。")
            }
            guard
                let mode = TranslationMode(
                    sourceLanguageTag: stored.sourceLanguage,
                    targetLanguageTag: stored.targetLanguage
                )
            else {
                return RecoverySessionCursor(
                    id: sessionID,
                    stored: stored,
                    entries: stored.entries,
                    unavailableMessage: "不支持该听抄稿保存的翻译语言组合。"
                )
            }
            await processor.configure(mode: mode)
            return RecoverySessionCursor(
                id: sessionID,
                stored: stored,
                entries: stored.entries,
                unavailableMessage: nil
            )
        } catch {
            return unavailableCursor(id: sessionID, message: error.localizedDescription)
        }
    }

    func replay(
        _ record: PendingUtteranceRecord,
        cursor: inout RecoverySessionCursor
    ) async {
        if let message = cursor.unavailableMessage {
            if cursor.issues.values.isEmpty {
                cursor.issues.append(
                    issue(sequence: record.id.sequenceNumber, message: message)
                )
            }
            return
        }
        let result = await replayRecord(record, entries: &cursor.entries)
        cursor.issues.append(contentsOf: result.issues)
        cursor.isBlocked = result.isBlocked
        let updatedCount = cursor.terminalRejectionCount.addingReportingOverflow(
            result.terminalRejectionCount
        )
        cursor.terminalRejectionCount = updatedCount.overflow ? Int.max : updatedCount.partialValue
    }

    func finalize(_ cursor: RecoverySessionCursor) async -> RecoveryCursorCloseResult {
        var issues = cursor.issues
        guard !cursor.isBlocked else {
            return RecoveryCursorCloseResult(issues: issues.values, isBlocked: true)
        }
        guard let stored = cursor.stored else {
            return RecoveryCursorCloseResult(issues: issues.values, isBlocked: false)
        }
        do {
            try Task.checkCancellation()
            try await finish(stored: stored, entries: cursor.entries)
        } catch is CancellationError {
            return RecoveryCursorCloseResult(issues: issues.values, isBlocked: true)
        } catch {
            issues.append(issue(message: error.localizedDescription))
            return RecoveryCursorCloseResult(issues: issues.values, isBlocked: true)
        }
        return RecoveryCursorCloseResult(issues: issues.values, isBlocked: false)
    }

    private func unavailableCursor(
        id: UUID,
        message: String
    ) -> RecoverySessionCursor {
        RecoverySessionCursor(
            id: id,
            stored: nil,
            entries: [],
            unavailableMessage: message
        )
    }
}

struct RecoveryCursorCloseResult: Sendable {
    let issues: [LiveSessionIssue]
    let isBlocked: Bool

    static let closedWithoutIssue = Self(issues: [], isBlocked: false)
}
