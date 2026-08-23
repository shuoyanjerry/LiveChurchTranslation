extension TranscriptEntry {
    /// Returns the same immutable entry with a durable source-segment identity.
    public func recordingSourceSegmentSequence(_ sourceSegmentSequence: UInt64) -> Self {
        copy(sequence: sequence, sourceSegmentSequence: sourceSegmentSequence)
    }

    /// Returns the same immutable entry with a new presentation order.
    public func recordingPresentationSequence(_ sequence: Int) -> Self {
        copy(sequence: sequence, sourceSegmentSequence: sourceSegmentSequence)
    }

    private func copy(
        sequence: Int,
        sourceSegmentSequence: UInt64?
    ) -> Self {
        Self(
            id: id,
            sequence: sequence,
            sourceSegmentSequence: sourceSegmentSequence,
            rawSourceText: rawSourceText,
            sourceText: sourceText,
            sourceCorrections: sourceCorrections,
            sourcePronounDecisions: sourcePronounDecisions,
            targetText: targetText,
            translationReview: translationReview,
            startedMilliseconds: startedMilliseconds,
            endedMilliseconds: endedMilliseconds,
            translationMilliseconds: translationMilliseconds,
            createdAt: createdAt
        )
    }
}
