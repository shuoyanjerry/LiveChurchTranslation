/// An observed pair from a strict full-character alignment.
public struct ASRPronounPairCount: Codable, Equatable, Hashable, Sendable {
    public let reference: String?
    public let hypothesis: String?
    public let count: Int
}

/// Occurrence-level confusion totals for `他`, `她`, `它`, and `祂`.
public struct ASRPronounConfusion: Codable, Equatable, Hashable, Sendable {
    public let pairs: [ASRPronounPairCount]
    public let referenceTotal: Int
    public let hypothesisTotal: Int
    public let correctTotal: Int
    public let substitutionTotal: Int
    public let deletionTotal: Int
    public let insertionTotal: Int

    public func count(reference: String?, hypothesis: String?) -> Int {
        pairs.first {
            $0.reference == reference && $0.hypothesis == hypothesis
        }?.count ?? 0
    }
}

extension ASRQualificationTextMetrics {
    /// Pronoun confusion derived from the normalized strict character alignment.
    public static func normalizedStrictPronounConfusion(
        reference: String,
        hypothesis: String
    ) -> ASRPronounConfusion {
        let alignment = ASRCharacterAligner.strict(
            reference: normalizedCharacters(reference),
            hypothesis: normalizedCharacters(hypothesis)
        )
        return ASRPronounConfusionBuilder.build(alignment.columns)
    }
}

private struct ASRPronounPair: Hashable {
    let reference: String?
    let hypothesis: String?
}

private struct ASRPronounTotals {
    var reference = 0
    var hypothesis = 0
    var correct = 0
    var substitution = 0
    var deletion = 0
    var insertion = 0

    mutating func record(reference: String?, hypothesis: String?) {
        if let reference, let hypothesis {
            self.reference += 1
            self.hypothesis += 1
            if reference == hypothesis {
                correct += 1
            } else {
                substitution += 1
            }
        } else if reference != nil {
            self.reference += 1
            deletion += 1
        } else if hypothesis != nil {
            self.hypothesis += 1
            insertion += 1
        }
    }
}

private enum ASRPronounConfusionBuilder {
    private static let pronouns: Set<Character> = ["他", "她", "它", "祂"]

    static func build(_ columns: [ASRCharacterAlignmentColumn]) -> ASRPronounConfusion {
        var counts: [ASRPronounPair: Int] = [:]
        var totals = ASRPronounTotals()
        for column in columns {
            let reference = pronoun(column.reference)
            let hypothesis = pronoun(column.hypothesis)
            guard reference != nil || hypothesis != nil else { continue }
            counts[.init(reference: reference, hypothesis: hypothesis), default: 0] += 1
            totals.record(reference: reference, hypothesis: hypothesis)
        }
        return result(counts: counts, totals: totals)
    }

    private static func result(
        counts: [ASRPronounPair: Int],
        totals: ASRPronounTotals
    ) -> ASRPronounConfusion {
        let pairs = counts.map {
            ASRPronounPairCount(
                reference: $0.key.reference,
                hypothesis: $0.key.hypothesis,
                count: $0.value
            )
        }.sorted(by: pairPrecedes)
        return ASRPronounConfusion(
            pairs: pairs,
            referenceTotal: totals.reference,
            hypothesisTotal: totals.hypothesis,
            correctTotal: totals.correct,
            substitutionTotal: totals.substitution,
            deletionTotal: totals.deletion,
            insertionTotal: totals.insertion
        )
    }

    private static func pronoun(_ character: Character?) -> String? {
        guard let character, pronouns.contains(character) else { return nil }
        return String(character)
    }

    private static func pairPrecedes(
        _ left: ASRPronounPairCount,
        _ right: ASRPronounPairCount
    ) -> Bool {
        let leftRanks = (rank(left.reference), rank(left.hypothesis))
        let rightRanks = (rank(right.reference), rank(right.hypothesis))
        return leftRanks < rightRanks
    }

    private static func rank(_ value: String?) -> Int {
        guard let value else { return 0 }
        return ["他", "她", "它", "祂"].firstIndex(of: value).map { $0 + 1 } ?? 5
    }
}
