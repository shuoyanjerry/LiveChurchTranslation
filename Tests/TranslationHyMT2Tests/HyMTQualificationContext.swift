import DiscourseResolutionAPI
import TranslationAPI

struct HyMTQualificationPersistedTurn: Sendable {
    let segmentID: String
    let sequence: Int
    let sourceText: String
    let targetText: String
}

struct HyMTQualificationContext {
    private var turnsBySource: [String: [HyMTQualificationPersistedTurn]] = [:]

    func latest(for sourceID: String) -> [HyMTQualificationPersistedTurn] {
        Array(turnsBySource[sourceID, default: []].suffix(2))
    }

    mutating func append(_ turn: HyMTQualificationPersistedTurn, sourceID: String) {
        turnsBySource[sourceID, default: []].append(turn)
    }
}

extension Array where Element == HyMTQualificationPersistedTurn {
    var segmentIDs: [String] { map(\.segmentID) }

    var discourseTurns: [VerifiedDiscourseTurn] {
        map { VerifiedDiscourseTurn(sequence: $0.sequence, text: $0.sourceText) }
    }

    var translationEntries: [TranslationContextEntry] {
        map { TranslationContextEntry(sourceText: $0.sourceText, targetText: $0.targetText) }
    }
}
