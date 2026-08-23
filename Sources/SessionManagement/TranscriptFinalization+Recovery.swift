import PersistenceAPI
import UtteranceRecoveryAPI

extension TranscriptFinalization {
    init(
        recovery summary: UtteranceRecoverySessionSummary,
        kind: Kind = .normal,
        hasUnrecoverableFailure: Bool = false
    ) {
        self.init(
            kind: kind,
            pendingRecordCount: summary.pendingRecordCount,
            rejections: summary.rejections.map {
                StoredTranscriptRejection(
                    sentenceID: $0.sentenceID,
                    sentenceOrdinal: $0.sentenceOrdinal,
                    stage: $0.stage.rawValue,
                    failureCode: $0.failureCode
                )
            },
            quarantinedArtifactCount: summary.quarantinedArtifactCount,
            hasUnrecoverableFailure: hasUnrecoverableFailure
        )
    }
}
