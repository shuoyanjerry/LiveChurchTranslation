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
    var issues: [LiveSessionIssue] = []
}

extension UtteranceRecoveryReplayer {
    func makeCursor(sessionID: UUID) async -> RecoverySessionCursor {
        do {
            guard let stored = try await dependencies.transcriptStore.load(sessionID: sessionID)
            else {
                return unavailableCursor(id: sessionID, message: "Transcript missing")
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
                    unavailableMessage: "The saved translation language pair is not supported."
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
            cursor.issues.append(
                issue(sequence: record.id.sequenceNumber, message: message)
            )
            return
        }
        if let replayIssue = await replay(record, entries: &cursor.entries) {
            cursor.issues.append(replayIssue)
        }
    }

    func finalize(_ cursor: RecoverySessionCursor) async -> [LiveSessionIssue] {
        var issues = cursor.issues
        if issues.isEmpty, let stored = cursor.stored {
            await finish(stored: stored, entries: cursor.entries, issues: &issues)
        }
        return issues
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

    private func replay(
        _ record: PendingUtteranceRecord,
        entries: inout [TranscriptEntry]
    ) async -> LiveSessionIssue? {
        do {
            try await replaySentences(record, entries: &entries)
            try await dependencies.recoveryStore.markCompleted(record.id)
            return nil
        } catch is IgnoredUtterance {
            return await completeIgnored(record)
        } catch let failure as UtteranceProcessingFailure {
            return issue(
                stage: failure.stage,
                sequence: record.id.sequenceNumber,
                message: failure.message
            )
        } catch {
            return issue(
                sequence: record.id.sequenceNumber,
                message: error.localizedDescription
            )
        }
    }

    private func replaySentences(
        _ record: PendingUtteranceRecord,
        entries: inout [TranscriptEntry]
    ) async throws {
        let context = contextEntries(from: entries, before: record.id.sequenceNumber)
        let inputs = try await processor.recognize(
            record.segment,
            discourseContext: context.discourse
        )
        var translationContext = context.translation
        for (ordinal, input) in inputs.enumerated() {
            if let existing = entries.first(where: {
                $0.id == input.utterance.sourceSegmentID
            }) {
                appendContext(existing, to: &translationContext)
                continue
            }
            let entry = try await processor.recoverEntry(
                record,
                input: input,
                translationContext: translationContext,
                presentationSequence: context.presentationSequence + ordinal
            )
            entries.append(entry)
            appendContext(entry, to: &translationContext)
        }
    }

    private func appendContext(
        _ entry: TranscriptEntry,
        to context: inout [TranslationContextEntry]
    ) {
        context.append(
            TranslationContextEntry(
                sourceText: entry.sourceText,
                targetText: entry.targetText
            )
        )
        if context.count > 2 {
            context.removeFirst(context.count - 2)
        }
    }

    private func completeIgnored(
        _ record: PendingUtteranceRecord
    ) async -> LiveSessionIssue? {
        do {
            try await dependencies.recoveryStore.markCompleted(record.id)
            return nil
        } catch {
            return issue(
                stage: .persistence,
                sequence: record.id.sequenceNumber,
                message: error.localizedDescription
            )
        }
    }
}
