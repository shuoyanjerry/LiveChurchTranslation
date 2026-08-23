import DiscourseResolutionAPI

struct DiscourseQualificationPersistedTurn: Sendable {
    let segmentID: String
    let sequence: Int
    let text: String
}

struct DiscourseQualificationContext {
    private var turnsBySource: [String: [DiscourseQualificationPersistedTurn]] = [:]

    func latest(for sourceID: String) -> [DiscourseQualificationPersistedTurn] {
        Array(turnsBySource[sourceID, default: []].suffix(2))
    }

    mutating func append(
        _ turn: DiscourseQualificationPersistedTurn,
        sourceID: String
    ) {
        turnsBySource[sourceID, default: []].append(turn)
    }
}

extension Array where Element == DiscourseQualificationPersistedTurn {
    var segmentIDs: [String] { map(\.segmentID) }

    var textSHA256s: [String] {
        map { DiscourseQualificationHash.text($0.text) }
    }

    var discourseTurns: [VerifiedDiscourseTurn] {
        map { VerifiedDiscourseTurn(sequence: $0.sequence, text: $0.text) }
    }
}
