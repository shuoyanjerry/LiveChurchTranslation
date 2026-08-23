struct ReferentAnchorScanner {
    private struct Term: Sendable {
        let text: String
        let referent: ResolutionReferent
    }

    private static let terms: [Term] =
        ReferentAnchorLexicon.deityTerms.map { Term(text: $0, referent: .deity) }
        + ReferentAnchorLexicon.femaleTerms.map { Term(text: $0, referent: .female) }
        + ReferentAnchorLexicon.maleTerms.map { Term(text: $0, referent: .male) }

    static func scan(_ text: String) -> [ReferentAnchor] {
        var anchors: [ReferentAnchor] = []
        var index = text.startIndex
        while index < text.endIndex {
            if let anchor = matchedAnchor(at: index, in: text) {
                anchors.append(anchor)
                index = anchor.range.upperBound
                continue
            }
            if text[index] == "神", let anchor = bareGodAnchor(at: index, in: text) {
                anchors.append(anchor)
            }
            index = text.index(after: index)
        }
        return anchors
    }

    private static func matchedAnchor(
        at index: String.Index,
        in text: String
    ) -> ReferentAnchor? {
        guard let term = terms.first(where: { text[index...].hasPrefix($0.text) }) else {
            return nil
        }
        return anchor(for: term, at: index, in: text)
    }

    private static func anchor(
        for term: Term,
        at index: String.Index,
        in text: String
    ) -> ReferentAnchor? {
        let upperBound = text.index(index, offsetBy: term.text.count)
        if term.referent == .deity {
            guard isLexicalStart(index, in: text) else { return nil }
            guard
                !ReferentAnchorLexicon.forbiddenDeityCompounds.contains(
                    where: text[index...].hasPrefix
                )
            else {
                return nil
            }
            guard isReferentialContinuation(upperBound, in: text) else { return nil }
        } else {
            guard isHumanLexicalStart(index, in: text) else { return nil }
            guard
                !ReferentAnchorLexicon.forbiddenHumanCompounds.contains(
                    where: text[index...].hasPrefix
                )
            else {
                return nil
            }
        }
        let plural = upperBound < text.endIndex && ["们", "們"].contains(text[upperBound])
        return ReferentAnchor(
            referent: term.referent,
            range: index..<upperBound,
            isPlural: plural
        )
    }

    private static func bareGodAnchor(
        at index: String.Index,
        in text: String
    ) -> ReferentAnchor? {
        guard isLexicalStart(index, in: text) else { return nil }
        let upperBound = text.index(after: index)
        guard isReferentialContinuation(upperBound, in: text) else { return nil }
        return ReferentAnchor(
            referent: .deity,
            range: index..<upperBound,
            isPlural: false
        )
    }

    private static func isLexicalStart(
        _ index: String.Index,
        in text: String
    ) -> Bool {
        guard index > text.startIndex else { return true }
        let previous = text[text.index(before: index)]
        return previous.isWhitespace
            || ReferentAnchorLexicon.lexicalBoundaries.contains(previous)
    }

    private static func isHumanLexicalStart(
        _ index: String.Index,
        in text: String
    ) -> Bool {
        if isLexicalStart(index, in: text) { return true }
        let prefix = text[..<index]
        return ReferentAnchorLexicon.humanLeadIns.contains(where: prefix.hasSuffix)
    }

    private static func isReferentialContinuation(
        _ index: String.Index,
        in text: String
    ) -> Bool {
        guard index < text.endIndex else { return true }
        let next = text[index]
        if next.isWhitespace || ReferentAnchorLexicon.lexicalBoundaries.contains(next) {
            return true
        }
        return ReferentAnchorLexicon.deityContinuations.contains {
            text[index...].hasPrefix($0)
        }
    }
}
