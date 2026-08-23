import ASRAPI
import Foundation
import TranslationAPI

public struct TranscriptSourceCorrection: Codable, Equatable, Sendable {
    public let observedText: String
    public let replacementText: String
    public let kind: TranscriptSourceCorrectionKind?
    public let reason: String?
    public let confidence: Double?
    public let evidenceSequence: Int?
    public let evidenceText: String?
    public let utf16Location: Int?
    public let utf16Length: Int?

    public init(
        observedText: String,
        replacementText: String,
        kind: TranscriptSourceCorrectionKind? = nil,
        reason: String? = nil,
        confidence: Double? = nil,
        evidenceSequence: Int? = nil,
        evidenceText: String? = nil,
        utf16Location: Int? = nil,
        utf16Length: Int? = nil
    ) {
        self.observedText = observedText
        self.replacementText = replacementText
        self.kind = kind
        self.reason = reason
        self.confidence = confidence
        self.evidenceSequence = evidenceSequence
        self.evidenceText = evidenceText
        self.utf16Location = utf16Location
        self.utf16Length = utf16Length
    }
}

public enum TranscriptSourceCorrectionKind: String, Codable, Equatable, Sendable {
    case recognitionNormalization
    case discoursePronoun
}

public enum TranscriptPronounResolution: String, Codable, Equatable, Sendable {
    case unresolvedSpokenMandarin
    case verifiedFemale
    case verifiedMale
    case verifiedDeity
}

public struct TranscriptSourcePronounDecision: Codable, Equatable, Sendable {
    public let resolution: TranscriptPronounResolution
    public let utf16Location: Int
    public let utf16Length: Int
    public let reason: String?
    public let confidence: Double?
    public let evidenceSequence: Int?
    public let evidenceText: String?

    public init(
        resolution: TranscriptPronounResolution,
        utf16Location: Int,
        utf16Length: Int,
        reason: String? = nil,
        confidence: Double? = nil,
        evidenceSequence: Int? = nil,
        evidenceText: String? = nil
    ) {
        self.resolution = resolution
        self.utf16Location = utf16Location
        self.utf16Length = utf16Length
        self.reason = reason
        self.confidence = confidence
        self.evidenceSequence = evidenceSequence
        self.evidenceText = evidenceText
    }
}

public struct TranscriptSourceAudit: Equatable, Sendable {
    public let rawText: String
    public let corrections: [TranscriptSourceCorrection]
    public let pronounDecisions: [TranscriptSourcePronounDecision]

    public init(
        rawText: String,
        corrections: [TranscriptSourceCorrection],
        pronounDecisions: [TranscriptSourcePronounDecision] = []
    ) {
        self.rawText = rawText
        self.corrections = corrections
        self.pronounDecisions = pronounDecisions
    }
}

public struct TranscriptEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    /// Stable VAD segment order within the containing session.
    public let sourceSegmentSequence: UInt64?
    /// Dense presentation order; never use this value for discourse evidence.
    public let sequence: Int
    public let rawSourceText: String
    public let sourceText: String
    public let sourceCorrections: [TranscriptSourceCorrection]
    public let sourcePronounDecisions: [TranscriptSourcePronounDecision]
    public let targetText: String
    public let startedMilliseconds: Int64
    public let endedMilliseconds: Int64
    public let translationMilliseconds: Int64
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sequence: Int,
        sourceSegmentSequence: UInt64? = nil,
        rawSourceText: String? = nil,
        sourceText: String,
        sourceCorrections: [TranscriptSourceCorrection] = [],
        sourcePronounDecisions: [TranscriptSourcePronounDecision] = [],
        targetText: String,
        startedMilliseconds: Int64,
        endedMilliseconds: Int64,
        translationMilliseconds: Int64,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sequence = sequence
        self.sourceSegmentSequence = sourceSegmentSequence
        self.rawSourceText = rawSourceText ?? sourceText
        self.sourceText = sourceText
        self.sourceCorrections = sourceCorrections
        self.sourcePronounDecisions = sourcePronounDecisions
        self.targetText = targetText
        self.startedMilliseconds = startedMilliseconds
        self.endedMilliseconds = endedMilliseconds
        self.translationMilliseconds = translationMilliseconds
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, sequence, sourceSegmentSequence, rawSourceText, sourceText, sourceCorrections
        case sourcePronounDecisions
        case targetText, startedMilliseconds, endedMilliseconds
        case translationMilliseconds, createdAt
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        sequence = try values.decode(Int.self, forKey: .sequence)
        sourceSegmentSequence = try values.decodeIfPresent(
            UInt64.self,
            forKey: .sourceSegmentSequence
        )
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
        targetText = try values.decode(String.self, forKey: .targetText)
        startedMilliseconds = try values.decode(Int64.self, forKey: .startedMilliseconds)
        endedMilliseconds = try values.decode(Int64.self, forKey: .endedMilliseconds)
        translationMilliseconds = try values.decode(Int64.self, forKey: .translationMilliseconds)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
    }
}
