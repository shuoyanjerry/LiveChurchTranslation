import DiscourseResolutionAPI
import Foundation
import SessionManagementAPI
import TranscriptAPI
import TranslationAPI
import UtteranceRecoveryAPI

extension UtteranceRecoveryReplayer {
    func finish(
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

    func contextEntries(
        from entries: [TranscriptEntry],
        before sequence: Int
    ) -> RecoveryProcessingContext {
        let recent = entries.filter { $0.sequence < sequence }
            .sorted { $0.sequence < $1.sequence }
            .suffix(2)
        return RecoveryProcessingContext(
            translation: recent.map {
                TranslationContextEntry(sourceText: $0.sourceText, targetText: $0.targetText)
            },
            discourse: recent.map {
                VerifiedDiscourseTurn(sequence: $0.sequence, text: $0.sourceText)
            }
        )
    }

    func sequenceOrder(
        _ left: PendingUtteranceRecord,
        _ right: PendingUtteranceRecord
    ) -> Bool {
        left.id.sequenceNumber < right.id.sequenceNumber
    }
}
