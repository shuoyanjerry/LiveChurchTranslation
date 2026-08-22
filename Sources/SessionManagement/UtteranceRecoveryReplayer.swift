import Foundation
import DiscourseResolutionAPI
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

    private func orderedSessionIDs(
        _ sessions: [UUID: [PendingUtteranceRecord]]
    ) -> [UUID] {
        sessions.keys.sorted {
            let left = sessions[$0]?.map(\.stagedAt).min() ?? .distantPast
            let right = sessions[$1]?.map(\.stagedAt).min() ?? .distantPast
            return left == right ? $0.uuidString < $1.uuidString : left < right
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
