import Foundation
import TranslationQualificationSupport

enum DiscourseQualificationReportValidator {
    static func validate(
        _ report: DiscourseQualificationReport,
        corpus: TranslationQualificationCorpus
    ) throws {
        guard report.schemaVersion == 1 else { throw invalidReport }
        guard report.manifestSHA256 == corpus.manifestSHA256 else { throw invalidReport }
        guard report.schemaSHA256 == corpus.schemaSHA256 else { throw invalidReport }
        guard report.segments.map(\.segmentID) == corpus.manifest.segments.map(\.id) else {
            throw invalidReport
        }
        guard report.aggregate.segmentCount == corpus.manifest.segments.count else {
            throw invalidReport
        }
        guard
            report.aggregate.occurrenceCount
                == corpus.manifest.summary.taGlyphOccurrenceCount
        else {
            throw invalidReport
        }
        try validateContext(report.segments)
        try validateOccurrences(report.segments, corpus: corpus)
    }

    private static func validateContext(
        _ segments: [DiscourseQualificationSegmentReport]
    ) throws {
        var persistedBySource: [String: [String]] = [:]
        for segment in segments {
            let expected = Array(persistedBySource[segment.sourceID, default: []].suffix(2))
            guard segment.contextSegmentIDs == expected else { throw invalidReport }
            guard segment.contextTextSHA256s.count == expected.count else {
                throw invalidReport
            }
            persistedBySource[segment.sourceID, default: []].append(segment.segmentID)
        }
    }

    private static func validateOccurrences(
        _ segments: [DiscourseQualificationSegmentReport],
        corpus: TranslationQualificationCorpus
    ) throws {
        let expectedByID = Dictionary(
            uniqueKeysWithValues: corpus.manifest.segments.map {
                ($0.id, $0.pronounOccurrences.map(\.id))
            }
        )
        for segment in segments {
            guard segment.occurrences.map(\.occurrenceID) == expectedByID[segment.segmentID] else {
                throw invalidReport
            }
            guard isSHA256(segment.inputSHA256), isSHA256(segment.resolvedSHA256) else {
                throw invalidReport
            }
            guard segment.contextTextSHA256s.allSatisfy(isSHA256) else {
                throw invalidReport
            }
        }
    }

    private static func isSHA256(_ value: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "0123456789abcdef")
        return value.count == 64 && value.unicodeScalars.allSatisfy(allowed.contains)
    }

    private static var invalidReport: TranslationQualificationError {
        .invalidReport("discourse qualification report invariant failed")
    }
}
