import Foundation
import SessionManagementAPI
import TranscriptAPI
import TranslationAPI
import UtteranceRecoveryAPI

struct UtteranceRecoveryReplayer: Sendable {
    let dependencies: LiveSessionDependencies
    let processor: UtteranceProcessor

    func replay() async -> [LiveSessionIssue] {
        let batch: UtteranceRecoveryBatch
        do {
            batch = try await dependencies.recoveryStore.recoverAllPending()
        } catch {
            return [issue(message: error.localizedDescription)]
        }
        var issues = batch.quarantined.map {
            issue(message: "A pending sentence was quarantined: \($0.reason.rawValue).")
        }
        let sessions = Dictionary(grouping: batch.pending, by: { $0.id.sessionID })
        for sessionID in orderedSessionIDs(sessions) {
            issues += await replaySession(
                id: sessionID,
                records: sessions[sessionID] ?? []
            )
        }
        return issues
    }

    private func replaySession(
        id: UUID,
        records: [PendingUtteranceRecord]
    ) async -> [LiveSessionIssue] {
        let stored: TranscriptSession
        do {
            guard let loaded = try await dependencies.transcriptStore.load(sessionID: id) else {
                return records.map { issue(sequence: $0.id.sequenceNumber, message: "Transcript missing") }
            }
            stored = loaded
        } catch {
            return records.map { issue(sequence: $0.id.sequenceNumber, message: error.localizedDescription) }
        }
        var entries = stored.entries
        var context = contextEntries(from: entries)
        var issues: [LiveSessionIssue] = []
        for record in records.sorted(by: sequenceOrder) {
            do {
                let entry = try await processor.recoverEntry(record, context: context)
                if !entries.contains(where: { $0.id == entry.id }) { entries.append(entry) }
                context = contextEntries(from: entries)
                try await dependencies.recoveryStore.markCompleted(record.id)
            } catch let failure as UtteranceProcessingFailure {
                issues.append(
                    issue(
                        stage: failure.stage,
                        sequence: record.id.sequenceNumber,
                        message: failure.message
                    )
                )
            } catch {
                issues.append(issue(sequence: record.id.sequenceNumber, message: error.localizedDescription))
            }
        }
        if issues.isEmpty {
            await finish(stored: stored, entries: entries, issues: &issues)
        }
        return issues
    }

    private func finish(
        stored: TranscriptSession,
        entries: [TranscriptEntry],
        issues: inout [LiveSessionIssue]
    ) async {
        do {
            try await dependencies.transcriptStore.finish(
                TranscriptSession(
                    id: stored.id,
                    startedAt: stored.startedAt,
                    endedAt: Date(),
                    entries: entries.sorted { $0.sequence < $1.sequence }
                )
            )
        } catch {
            issues.append(issue(message: error.localizedDescription))
        }
    }

    private func orderedSessionIDs(
        _ sessions: [UUID: [PendingUtteranceRecord]]
    ) -> [UUID] {
        sessions.keys.sorted {
            let left = sessions[$0]?.map(\.stagedAt).min() ?? .distantPast
            let right = sessions[$1]?.map(\.stagedAt).min() ?? .distantPast
            return left == right ? $0.uuidString < $1.uuidString : left < right
        }
    }

    private func contextEntries(from entries: [TranscriptEntry]) -> [TranslationContextEntry] {
        entries.sorted { $0.sequence < $1.sequence }.suffix(2).map {
            TranslationContextEntry(sourceText: $0.sourceText, targetText: $0.targetText)
        }
    }

    private func sequenceOrder(
        _ left: PendingUtteranceRecord,
        _ right: PendingUtteranceRecord
    ) -> Bool {
        left.id.sequenceNumber < right.id.sequenceNumber
    }

    private func issue(
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
