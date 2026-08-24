import Foundation
import TranslationAPI
import TranslationQualificationSupport
@testable import TranslationHyMT2

struct HyMTQualificationTraceMapping {
    let observations: [TranslationPronounRealizationObservation]
    let integrityCheck: TranslationQualificationCheck
}

enum HyMTQualificationTraceMapper {
    static func map(
        segment: TranslationQualificationSegment,
        guidance: [TranslationPronounGuidance],
        traces: [HyMT2PronounTraceObservation],
        summary: HyMTQualificationAttemptSummary,
        hasHypothesis: Bool
    ) -> HyMTQualificationTraceMapping {
        guard !guidance.isEmpty else {
            return mapping(traces.isEmpty ? .notApplicable : .fail, observations: [])
        }
        guard hasHypothesis else {
            return mapping(traces.isEmpty ? .notApplicable : .fail, observations: [])
        }
        guard let phase = selectedPhase(summary, traces: traces) else {
            return mapping(.fail, observations: [])
        }
        let expected = Dictionary(uniqueKeysWithValues: guidance.map { ($0.sourceRange, $0.resolution) })
        let occurrences = occurrenceIDs(segment)
        guard traces.count == expected.count else { return mapping(.fail, observations: []) }
        var seen = Set<TranslationSourceRange>()
        var observations: [TranslationPronounRealizationObservation] = []
        for trace in traces {
            guard
                trace.phase == phase,
                seen.insert(trace.sourceRange).inserted,
                expected[trace.sourceRange] == trace.resolution,
                let occurrenceID = occurrences[trace.sourceRange]
            else { return mapping(.fail, observations: []) }
            observations.append(
                TranslationPronounRealizationObservation(
                    occurrenceID: occurrenceID,
                    resolution: trace.resolution.rawValue,
                    realizationClass: trace.realizationClass.rawValue
                )
            )
        }
        return mapping(.pass, observations: observations)
    }

    private static func acceptedPhase(
        _ summary: HyMTQualificationAttemptSummary
    ) -> HyMT2AttemptPhase? {
        switch summary.outcomes.last {
        case "initial.accepted": .initial
        case "strictRetry.accepted": .strictRetry
        default: nil
        }
    }

    private static func selectedPhase(
        _ summary: HyMTQualificationAttemptSummary,
        traces: [HyMT2PronounTraceObservation]
    ) -> HyMT2AttemptPhase? {
        if let phase = acceptedPhase(summary) { return phase }
        guard let phase = traces.first?.phase,
            traces.allSatisfy({ $0.phase == phase }),
            summary.outcomes.contains("\(phase.rawValue).validationRejected")
        else { return nil }
        return phase
    }

    private static func occurrenceIDs(
        _ segment: TranslationQualificationSegment
    ) -> [TranslationSourceRange: String] {
        Dictionary(
            uniqueKeysWithValues: segment.pronounOccurrences.compactMap { occurrence in
                guard occurrence.tokenClass == .singularPronoun else { return nil }
                let scalars = segment.observedASRAmbiguousChinese.unicodeScalars
                let index = scalars.index(scalars.startIndex, offsetBy: occurrence.unicodeScalarOffset)
                let location = String(scalars[..<index]).utf16.count
                let glyph = String(scalars[index])
                return (
                    TranslationSourceRange(location: location, length: glyph.utf16.count),
                    occurrence.id
                )
            })
    }

    private static func mapping(
        _ status: TranslationQualificationCheckStatus,
        observations: [TranslationPronounRealizationObservation]
    ) -> HyMTQualificationTraceMapping {
        HyMTQualificationTraceMapping(
            observations: observations,
            integrityCheck: TranslationQualificationCheck(
                kind: "pronounTraceIntegrity",
                status: status
            )
        )
    }
}
