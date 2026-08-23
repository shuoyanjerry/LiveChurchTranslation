import TranslationQualificationSupport

enum DiscourseQualificationReportBuilder {
    static func build(
        corpus: TranslationQualificationCorpus,
        segments: [DiscourseQualificationSegmentReport]
    ) -> DiscourseQualificationReport {
        let sourceIDs = Set(segments.map(\.sourceID)).sorted()
        let sourceMetrics = sourceIDs.map { sourceID in
            DiscourseQualificationSourceMetrics(
                sourceID: sourceID,
                metrics: DiscourseQualificationMetricsBuilder.build(
                    segments.filter { $0.sourceID == sourceID }
                )
            )
        }
        return DiscourseQualificationReport(
            schemaVersion: 1,
            corpusID: corpus.manifest.corpusID,
            manifestSHA256: corpus.manifestSHA256,
            schemaSHA256: corpus.schemaSHA256,
            resolver: DiscourseQualificationResolverMetadata(
                identifier: "DiscourseResolutionCore.DiscourseResolver",
                contextWindowCount: 2,
                persistenceClass: "everyCompletedResolverTurn",
                orderingClass: "manifestOrderPartitionedBySource"
            ),
            aggregate: DiscourseQualificationMetricsBuilder.build(segments),
            sources: sourceMetrics,
            segments: segments
        )
    }
}
