struct ASRCharacterAlignment: Sendable {
    let editCount: Int
    let columns: [ASRCharacterAlignmentColumn]
}

struct ASRCharacterAlignmentColumn: Sendable {
    let reference: Character?
    let hypothesis: Character?
}

enum ASRCharacterAligner {
    static func strict(
        reference: [Character],
        hypothesis: [Character]
    ) -> ASRCharacterAlignment {
        let costs = costMatrix(
            reference: reference,
            hypothesis: hypothesis,
            freeHypothesisPrefix: false
        )
        return ASRCharacterAlignment(
            editCount: costs[reference.count][hypothesis.count],
            columns: strictBacktrace(reference: reference, hypothesis: hypothesis, costs: costs)
        )
    }

    static func edgeFreeSemiglobalEditCount(
        reference: [Character],
        hypothesis: [Character]
    ) -> Int {
        let costs = costMatrix(
            reference: reference,
            hypothesis: hypothesis,
            freeHypothesisPrefix: true
        )
        return costs[reference.count].min() ?? reference.count
    }
}

extension ASRCharacterAligner {
    private static func costMatrix(
        reference: [Character],
        hypothesis: [Character],
        freeHypothesisPrefix: Bool
    ) -> [[Int]] {
        var costs = Array(
            repeating: Array(repeating: 0, count: hypothesis.count + 1),
            count: reference.count + 1
        )
        for offset in reference.indices {
            costs[offset + 1][0] = offset + 1
        }
        if !freeHypothesisPrefix {
            for offset in hypothesis.indices {
                costs[0][offset + 1] = offset + 1
            }
        }
        fillCosts(reference: reference, hypothesis: hypothesis, costs: &costs)
        return costs
    }

    private static func fillCosts(
        reference: [Character],
        hypothesis: [Character],
        costs: inout [[Int]]
    ) {
        for referenceOffset in reference.indices {
            for hypothesisOffset in hypothesis.indices {
                let substitution =
                    costs[referenceOffset][hypothesisOffset]
                    + (reference[referenceOffset] == hypothesis[hypothesisOffset] ? 0 : 1)
                costs[referenceOffset + 1][hypothesisOffset + 1] = min(
                    substitution,
                    costs[referenceOffset][hypothesisOffset + 1] + 1,
                    costs[referenceOffset + 1][hypothesisOffset] + 1
                )
            }
        }
    }

    private static func strictBacktrace(
        reference: [Character],
        hypothesis: [Character],
        costs: [[Int]]
    ) -> [ASRCharacterAlignmentColumn] {
        var referenceIndex = reference.count
        var hypothesisIndex = hypothesis.count
        var reversed: [ASRCharacterAlignmentColumn] = []
        while referenceIndex > 0 || hypothesisIndex > 0 {
            let column = nextStrictColumn(
                reference: reference,
                hypothesis: hypothesis,
                costs: costs,
                referenceIndex: &referenceIndex,
                hypothesisIndex: &hypothesisIndex
            )
            reversed.append(column)
        }
        return reversed.reversed()
    }

    private static func nextStrictColumn(
        reference: [Character],
        hypothesis: [Character],
        costs: [[Int]],
        referenceIndex: inout Int,
        hypothesisIndex: inout Int
    ) -> ASRCharacterAlignmentColumn {
        if isDiagonal(reference, hypothesis, costs, referenceIndex, hypothesisIndex) {
            referenceIndex -= 1
            hypothesisIndex -= 1
            return .init(
                reference: reference[referenceIndex],
                hypothesis: hypothesis[hypothesisIndex]
            )
        }
        let isDeletion =
            referenceIndex > 0
            && costs[referenceIndex][hypothesisIndex]
                == costs[referenceIndex - 1][hypothesisIndex] + 1
        if isDeletion {
            referenceIndex -= 1
            return .init(reference: reference[referenceIndex], hypothesis: nil)
        }
        hypothesisIndex -= 1
        return .init(reference: nil, hypothesis: hypothesis[hypothesisIndex])
    }

    private static func isDiagonal(
        _ reference: [Character],
        _ hypothesis: [Character],
        _ costs: [[Int]],
        _ referenceIndex: Int,
        _ hypothesisIndex: Int
    ) -> Bool {
        guard referenceIndex > 0, hypothesisIndex > 0 else { return false }
        let penalty = reference[referenceIndex - 1] == hypothesis[hypothesisIndex - 1] ? 0 : 1
        return costs[referenceIndex][hypothesisIndex]
            == costs[referenceIndex - 1][hypothesisIndex - 1] + penalty
    }
}
