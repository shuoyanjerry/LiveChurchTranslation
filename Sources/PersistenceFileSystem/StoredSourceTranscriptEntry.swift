import Foundation
import TranscriptAPI

/// The durable transcript representation. Translation text remains live-only.
struct StoredSourceTranscriptEntry: Codable, Sendable {
    let id: UUID
    let sourceSegmentSequence: UInt64?
    let sequence: Int
    let rawSourceText: String
    let sourceText: String
    let sourceCorrections: [TranscriptSourceCorrection]
    let sourcePronounDecisions: [TranscriptSourcePronounDecision]
    let startedMilliseconds: Int64
    let endedMilliseconds: Int64
    let createdAt: Date

    init(_ entry: TranscriptEntry) {
        id = entry.id
        sourceSegmentSequence = entry.sourceSegmentSequence
        sequence = entry.sequence
        rawSourceText = entry.rawSourceText
        sourceText = entry.sourceText
        sourceCorrections = entry.sourceCorrections
        sourcePronounDecisions = entry.sourcePronounDecisions
        startedMilliseconds = entry.startedMilliseconds
        endedMilliseconds = entry.endedMilliseconds
        createdAt = entry.createdAt
    }

    var transcriptEntry: TranscriptEntry {
        TranscriptEntry(
            id: id,
            sequence: sequence,
            sourceSegmentSequence: sourceSegmentSequence,
            rawSourceText: rawSourceText,
            sourceText: sourceText,
            sourceCorrections: sourceCorrections,
            sourcePronounDecisions: sourcePronounDecisions,
            targetText: "",
            translationReview: nil,
            startedMilliseconds: startedMilliseconds,
            endedMilliseconds: endedMilliseconds,
            translationMilliseconds: 0,
            createdAt: createdAt
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, sourceSegmentSequence, sequence, rawSourceText, sourceText, sourceCorrections
        case sourcePronounDecisions, startedMilliseconds, endedMilliseconds
        case createdAt
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        sourceSegmentSequence = try values.decodeIfPresent(
            UInt64.self,
            forKey: .sourceSegmentSequence
        )
        sequence = try values.decode(Int.self, forKey: .sequence)
        sourceText = try values.decode(String.self, forKey: .sourceText)
        rawSourceText = try values.decodeIfPresent(String.self, forKey: .rawSourceText) ?? sourceText
        sourceCorrections =
            try values.decodeIfPresent(
                [TranscriptSourceCorrection].self,
                forKey: .sourceCorrections
            ) ?? []
        sourcePronounDecisions =
            try values.decodeIfPresent(
                [TranscriptSourcePronounDecision].self,
                forKey: .sourcePronounDecisions
            ) ?? []
        startedMilliseconds = try values.decode(Int64.self, forKey: .startedMilliseconds)
        endedMilliseconds = try values.decode(Int64.self, forKey: .endedMilliseconds)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encodeIfPresent(sourceSegmentSequence, forKey: .sourceSegmentSequence)
        try values.encode(sequence, forKey: .sequence)
        try values.encode(rawSourceText, forKey: .rawSourceText)
        try values.encode(sourceText, forKey: .sourceText)
        try values.encode(sourceCorrections, forKey: .sourceCorrections)
        try values.encode(sourcePronounDecisions, forKey: .sourcePronounDecisions)
        try values.encode(startedMilliseconds, forKey: .startedMilliseconds)
        try values.encode(endedMilliseconds, forKey: .endedMilliseconds)
        try values.encode(createdAt, forKey: .createdAt)
    }
}
