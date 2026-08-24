import Foundation
import SessionManagementAPI
import TranscriptAPI

extension LiveSessionCoordinator {
    func publishCommitted(_ entry: TranscriptEntry, sentenceTail: Duration) {
        state.append(entry)
        publish(.transcriptAppended(entry))
        recordVisibility(of: entry, sentenceTail: sentenceTail)
    }

    func transitionWhileActive(to phase: LiveSessionPhase, message: String) {
        guard isActive else { return }
        state.transition(to: phase, message: message)
        publishState()
    }

    func transitionForRecognizedSource() {
        if processingPolicy.transcribesOnly {
            transitionWhileActive(to: .recognizing, message: "正在整理听抄…")
        } else {
            transitionWhileActive(to: .translating, message: "正在忠实翻译…")
        }
    }

    private func recordVisibility(
        of entry: TranscriptEntry,
        sentenceTail: Duration
    ) {
        guard let anchor = sentenceAudioTimelineAnchor else { return }
        let event = SentenceRealtimePolicy.diagnostic(
            sourceSegmentSequence: entry.sourceSegmentSequence ?? 0,
            presentationSequence: entry.sequence,
            sentenceTail: sentenceTail,
            tailObservedAt: anchor.monotonicTime(for: sentenceTail),
            visibleAt: sentenceVisibilityClock.now()
        )
        let diagnostics = dependencies.diagnostics
        Task { await diagnostics.record(event) }
    }
}
