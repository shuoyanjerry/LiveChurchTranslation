import Foundation
import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI

extension UtteranceRecoveryReplayer {
    func replaySession(
        id: UUID,
        records: [PendingUtteranceRecord]
    ) async -> [LiveSessionIssue] {
        switch await loadSession(id: id, records: records) {
        case .failed(let issues):
            return issues
        case .loaded(let stored):
            var entries = stored.entries
            var issues: [LiveSessionIssue] = []
            for record in records.sorted(by: sequenceOrder) {
                if let issue = await replay(record, entries: &entries) {
                    issues.append(issue)
                }
            }
            if issues.isEmpty {
                await finish(stored: stored, entries: entries, issues: &issues)
            }
            return issues
        }
    }

    private func loadSession(
        id: UUID,
        records: [PendingUtteranceRecord]
    ) async -> RecoverySessionLoad {
        do {
            guard let stored = try await dependencies.transcriptStore.load(sessionID: id) else {
                let issues = records.map {
                    issue(sequence: $0.id.sequenceNumber, message: "Transcript missing")
                }
                return .failed(issues)
            }
            return .loaded(stored)
        } catch {
            let issues = records.map {
                issue(sequence: $0.id.sequenceNumber, message: error.localizedDescription)
            }
            return .failed(issues)
        }
    }

    private func replay(
        _ record: PendingUtteranceRecord,
        entries: inout [TranscriptEntry]
    ) async -> LiveSessionIssue? {
        do {
            let context = contextEntries(
                from: entries,
                before: Int(clamping: record.id.sequenceNumber)
            )
            let entry = try await processor.recoverEntry(record, context: context)
            if !entries.contains(where: { $0.id == entry.id }) { entries.append(entry) }
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

private enum RecoverySessionLoad {
    case loaded(TranscriptSession)
    case failed([LiveSessionIssue])
}
