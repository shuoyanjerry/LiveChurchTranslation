import DiscourseResolutionAPI
import TranslationQualificationSupport

struct DiscourseQualificationRunner {
    let resolver: any DiscourseResolving

    func run(
        _ corpus: TranslationQualificationCorpus
    ) throws -> [DiscourseQualificationSegmentReport] {
        var context = DiscourseQualificationContext()
        var reports: [DiscourseQualificationSegmentReport] = []
        for segment in corpus.manifest.segments {
            let recent = context.latest(for: segment.sourceID)
            let result = resolver.resolve(
                DiscourseResolutionRequest(
                    currentSequence: segment.sequence,
                    currentText: segment.observedASRAmbiguousChinese,
                    verifiedTurns: recent.discourseTurns
                )
            )
            try validate(result, input: segment.observedASRAmbiguousChinese)
            let evaluation = try DiscourseQualificationGuidanceEvaluator.evaluate(
                segment: segment,
                guidance: result.pronounGuidance
            )
            reports.append(
                report(segment: segment, recent: recent, result: result, evaluation: evaluation)
            )
            context.append(
                DiscourseQualificationPersistedTurn(
                    segmentID: segment.id,
                    sequence: segment.sequence,
                    text: result.resolvedText
                ),
                sourceID: segment.sourceID
            )
        }
        return reports
    }

    private func report(
        segment: TranslationQualificationSegment,
        recent: [DiscourseQualificationPersistedTurn],
        result: DiscourseResolutionResult,
        evaluation: DiscourseQualificationGuidanceEvaluation
    ) -> DiscourseQualificationSegmentReport {
        DiscourseQualificationSegmentReport(
            segmentID: segment.id,
            sourceID: segment.sourceID,
            sequence: segment.sequence,
            inputSHA256: DiscourseQualificationHash.text(segment.observedASRAmbiguousChinese),
            resolvedSHA256: DiscourseQualificationHash.text(result.resolvedText),
            contextSegmentIDs: recent.segmentIDs,
            contextTextSHA256s: recent.textSHA256s,
            correctionCount: result.corrections.count,
            correctionClasses: result.corrections.map {
                "\($0.kind.rawValue).\($0.reason.rawValue)"
            },
            guidanceCount: result.pronounGuidance.count,
            unmappedGuidanceCount: evaluation.unmappedGuidanceCount,
            duplicateGuidanceLocationCount: evaluation.duplicateGuidanceLocationCount,
            ambiguityClasses: result.ambiguities.map(\.rawValue),
            constraintClasses: result.constraints.map(\.rawValue),
            occurrences: evaluation.occurrences
        )
    }

    private func validate(
        _ result: DiscourseResolutionResult,
        input: String
    ) throws {
        guard result.originalText == input else {
            throw TranslationQualificationError.invalidReport(
                "resolver result did not preserve its input identity"
            )
        }
    }
}
