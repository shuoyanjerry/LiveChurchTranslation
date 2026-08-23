private struct ASRQualificationPronounPairKey: Hashable {
    let reference: String?
    let hypothesis: String?
}

enum ASRQualificationReportV3AggregateBuilder {
    static func build(
        _ clips: [ASRQualificationClipReportV3]
    ) throws -> ASRQualificationAggregateReportV3 {
        let decodedSeconds = try ASRQualificationReportV3Math.finiteSum(
            clips.map(\.decodedInputSeconds),
            path: "aggregate.decodedInputSeconds"
        )
        return ASRQualificationAggregateReportV3(
            clipCount: clips.count,
            sourceAudioSeconds: try duration(\.sourceAudioSeconds, clips: clips),
            decodedInputSeconds: decodedSeconds,
            unionCoveredSourceSeconds: try duration(\.unionCoveredSourceSeconds, clips: clips),
            strictCER: try microMeasurement(clips.map(\.strictCER), path: "aggregate.strictCER"),
            edgeFreeSemiglobalCER: try optionalEdgeMeasurement(clips),
            strictPronounConfusion: try mergePronouns(clips.map(\.strictPronounConfusion)),
            timing: try ASRQualificationReportV3Math.timing(
                attempts: clips.flatMap(\.attempts),
                decodedInputSeconds: decodedSeconds,
                path: "aggregate"
            )
        )
    }

    private static func duration(
        _ keyPath: KeyPath<ASRQualificationClipReportV3, Double>,
        clips: [ASRQualificationClipReportV3]
    ) throws -> Double {
        try ASRQualificationReportV3Math.finiteSum(
            clips.map { $0[keyPath: keyPath] },
            path: "aggregate.duration"
        )
    }

    private static func optionalEdgeMeasurement(
        _ clips: [ASRQualificationClipReportV3]
    ) throws -> ASRCharacterErrorMeasurement? {
        guard !clips.isEmpty, clips.allSatisfy({ $0.edgeFreeSemiglobalCER != nil }) else {
            return nil
        }
        let metrics = clips.compactMap(\.edgeFreeSemiglobalCER)
        return try microMeasurement(metrics, path: "aggregate.edgeFreeSemiglobalCER")
    }

    private static func microMeasurement(
        _ metrics: [ASRCharacterErrorMeasurement],
        path: String
    ) throws -> ASRCharacterErrorMeasurement {
        let edits = try ASRQualificationReportV3Math.checkedSum(
            metrics.map(\.editCount),
            path: "\(path).editCount"
        )
        let references = try ASRQualificationReportV3Math.checkedSum(
            metrics.map(\.referenceCharacterCount),
            path: "\(path).referenceCharacterCount"
        )
        return ASRCharacterErrorMeasurement(
            editCount: edits,
            referenceCharacterCount: references
        )
    }

    private static func mergePronouns(
        _ metrics: [ASRPronounConfusion]
    ) throws -> ASRPronounConfusion {
        var counts: [ASRQualificationPronounPairKey: Int] = [:]
        for metric in metrics {
            for pair in metric.pairs {
                let key = ASRQualificationPronounPairKey(
                    reference: pair.reference,
                    hypothesis: pair.hypothesis
                )
                counts[key] = try ASRQualificationReportV3Math.checkedAdd(
                    counts[key, default: 0],
                    pair.count,
                    path: "aggregate.strictPronounConfusion.pairs"
                )
            }
        }
        return try confusion(counts: counts, metrics: metrics)
    }

    private static func confusion(
        counts: [ASRQualificationPronounPairKey: Int],
        metrics: [ASRPronounConfusion]
    ) throws -> ASRPronounConfusion {
        let pairs = counts.map {
            ASRPronounPairCount(
                reference: $0.key.reference,
                hypothesis: $0.key.hypothesis,
                count: $0.value
            )
        }.sorted(by: pairPrecedes)
        return ASRPronounConfusion(
            pairs: pairs,
            referenceTotal: try total(\.referenceTotal, metrics: metrics, name: "reference"),
            hypothesisTotal: try total(\.hypothesisTotal, metrics: metrics, name: "hypothesis"),
            correctTotal: try total(\.correctTotal, metrics: metrics, name: "correct"),
            substitutionTotal: try total(\.substitutionTotal, metrics: metrics, name: "substitution"),
            deletionTotal: try total(\.deletionTotal, metrics: metrics, name: "deletion"),
            insertionTotal: try total(\.insertionTotal, metrics: metrics, name: "insertion")
        )
    }

    private static func total(
        _ keyPath: KeyPath<ASRPronounConfusion, Int>,
        metrics: [ASRPronounConfusion],
        name: String
    ) throws -> Int {
        try ASRQualificationReportV3Math.checkedSum(
            metrics.map { $0[keyPath: keyPath] },
            path: "aggregate.strictPronounConfusion.\(name)Total"
        )
    }

    private static func pairPrecedes(
        _ left: ASRPronounPairCount,
        _ right: ASRPronounPairCount
    ) -> Bool {
        (rank(left.reference), rank(left.hypothesis))
            < (rank(right.reference), rank(right.hypothesis))
    }

    private static func rank(_ value: String?) -> Int {
        guard let value else { return 0 }
        return ["他", "她", "它", "祂"].firstIndex(of: value).map { $0 + 1 } ?? 5
    }
}
