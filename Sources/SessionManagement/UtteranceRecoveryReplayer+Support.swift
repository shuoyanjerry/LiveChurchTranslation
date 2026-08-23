import DiscourseResolutionAPI
import Foundation
import PersistenceAPI
import SessionManagementAPI
import TranscriptAPI
import TranslationAPI
import UtteranceRecoveryAPI

extension UtteranceRecoveryReplayer {
    func finish(
        stored: TranscriptSession,
        entries: [TranscriptEntry]
    ) async throws {
        let recovery = try await dependencies.recoveryStore.summary(for: stored.id)
        try await dependencies.transcriptStore.finish(
            TranscriptSession(
                id: stored.id,
                startedAt: stored.startedAt,
                endedAt: Date(),
                entries: presentationEntries(from: entries),
                title: stored.title,
                kind: stored.kind,
                sourceLanguage: stored.sourceLanguage,
                targetLanguage: stored.targetLanguage
            ),
            finalization: TranscriptFinalization(recovery: recovery)
        )
    }

    func contextEntries(
        from entries: [TranscriptEntry],
        before sourceSequence: UInt64
    ) -> RecoveryProcessingContext {
        let earlier = entries.compactMap { entry -> SequencedRecoveryEntry? in
            guard let sequence = entry.sourceSegmentSequence,
                sequence < sourceSequence
            else { return nil }
            return SequencedRecoveryEntry(sourceSequence: sequence, entry: entry)
        }
        .sorted(by: recoverySourceOrder)
        let recentApproved = earlier.filter { $0.entry.translationReview == nil }.suffix(2)
        return RecoveryProcessingContext(
            presentationSequence: recoveredPresentationSequence(
                in: entries,
                sourceSequence: sourceSequence
            ),
            translation: recentApproved.map {
                TranslationContextEntry(
                    sourceText: $0.entry.sourceText,
                    targetText: $0.entry.targetText
                )
            },
            discourse: discourseTurns(from: earlier)
        )
    }

    func presentationEntries(from entries: [TranscriptEntry]) -> [TranscriptEntry] {
        guard entries.allSatisfy({ $0.sourceSegmentSequence != nil }) else {
            return entries.sorted(by: presentationOrder)
        }
        return entries.sorted(by: sourceOrder).enumerated().map { index, entry in
            entry.recordingPresentationSequence(index + 1)
        }
    }

    func sequenceOrder(
        _ left: PendingUtteranceRecord,
        _ right: PendingUtteranceRecord
    ) -> Bool {
        left.id.sequenceNumber < right.id.sequenceNumber
    }

    private func recoveredPresentationSequence(
        in entries: [TranscriptEntry],
        sourceSequence: UInt64
    ) -> Int {
        guard entries.allSatisfy({ $0.sourceSegmentSequence != nil }) else {
            return (entries.map(\.sequence).max() ?? 0) + 1
        }
        return entries.filter {
            guard let sequence = $0.sourceSegmentSequence else { return false }
            return sequence < sourceSequence
        }.count + 1
    }

    private func discourseTurns(
        from entries: [SequencedRecoveryEntry]
    ) -> [VerifiedDiscourseTurn] {
        let grouped = Dictionary(grouping: entries, by: \.sourceSequence)
        return grouped.keys.sorted().suffix(2).compactMap { sequence in
            guard let values = grouped[sequence] else { return nil }
            let text = values.sorted(by: recoverySourceOrder)
                .map(\.entry.sourceText)
                .joined(separator: " ")
            return VerifiedDiscourseTurn(
                sequence: Int(clamping: sequence),
                text: text
            )
        }
    }

    private func recoverySourceOrder(
        _ left: SequencedRecoveryEntry,
        _ right: SequencedRecoveryEntry
    ) -> Bool {
        if left.sourceSequence != right.sourceSequence {
            return left.sourceSequence < right.sourceSequence
        }
        return presentationOrder(left.entry, right.entry)
    }

    private func sourceOrder(_ left: TranscriptEntry, _ right: TranscriptEntry) -> Bool {
        guard left.sourceSegmentSequence == right.sourceSegmentSequence else {
            return (left.sourceSegmentSequence ?? 0) < (right.sourceSegmentSequence ?? 0)
        }
        return presentationOrder(left, right)
    }

    private func presentationOrder(_ left: TranscriptEntry, _ right: TranscriptEntry) -> Bool {
        if left.sequence != right.sequence { return left.sequence < right.sequence }
        return left.id.uuidString < right.id.uuidString
    }
}

private struct SequencedRecoveryEntry {
    let sourceSequence: UInt64
    let entry: TranscriptEntry
}
