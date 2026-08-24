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
    let processingStyle: RecoveredSessionProcessingStyle?
    var issues = BoundedLiveSessionIssueBuffer()
    var isBlocked = false
    var terminalRejectionCount = 0
}

enum RecoveredSessionProcessingStyle: Sendable {
    case sourceOnly
    case translated
}

extension UtteranceRecoveryReplayer {
    func makeCursor(sessionID: UUID) async -> RecoverySessionCursor {
        do {
            guard let stored = try await dependencies.transcriptStore.load(sessionID: sessionID)
            else {
                return unavailableCursor(id: sessionID, message: "找不到对应的听抄稿。")
            }
            guard let processingStyle = processingStyle(for: stored) else {
                return skippedCursor(id: sessionID)
            }
            guard let mode = recoveryMode(for: stored) else {
                return RecoverySessionCursor(
                    id: sessionID,
                    stored: stored,
                    entries: stored.entries,
                    unavailableMessage: "不支持该听抄稿保存的语音识别语言。",
                    processingStyle: nil
                )
            }
            await processor.configure(mode: mode)
            return RecoverySessionCursor(
                id: sessionID,
                stored: stored,
                entries: stored.entries,
                unavailableMessage: nil,
                processingStyle: processingStyle
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
        guard let processingStyle = cursor.processingStyle else { return }
        let result = await replayRecord(
            record,
            entries: &cursor.entries,
            processingStyle: processingStyle
        )
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
            unavailableMessage: message,
            processingStyle: nil
        )
    }

    private func skippedCursor(id: UUID) -> RecoverySessionCursor {
        RecoverySessionCursor(
            id: id,
            stored: nil,
            entries: [],
            unavailableMessage: nil,
            processingStyle: nil
        )
    }

    private func processingStyle(
        for stored: TranscriptSession
    ) -> RecoveredSessionProcessingStyle? {
        switch stored.kind {
        case .importedAudio: .sourceOnly
        case .live: allowsTranslatedSessions ? .translated : nil
        }
    }

    private func recoveryMode(for stored: TranscriptSession) -> TranslationMode? {
        guard stored.kind == .importedAudio else {
            return TranslationMode(
                sourceLanguageTag: stored.sourceLanguage,
                targetLanguageTag: stored.targetLanguage
            )
        }
        let tag = stored.sourceLanguage.lowercased().replacingOccurrences(of: "_", with: "-")
        let isMandarin =
            tag == "zh" || tag == "zh-hans" || tag.hasPrefix("zh-hans-")
            || tag == "zh-cn" || tag.hasPrefix("zh-cn-")
        if isMandarin { return .mandarinToEnglish }
        if tag == "en" || tag.hasPrefix("en-") { return .englishToSimplifiedChinese }
        return nil
    }
}

struct RecoveryCursorCloseResult: Sendable {
    let issues: [LiveSessionIssue]
    let isBlocked: Bool

    static let closedWithoutIssue = Self(issues: [], isBlocked: false)
}
