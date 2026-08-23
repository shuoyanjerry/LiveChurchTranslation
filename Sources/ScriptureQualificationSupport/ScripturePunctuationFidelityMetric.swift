public struct ScripturePunctuationFidelity: Codable, Equatable, Sendable {
    public let referencePunctuationCount: Int
    public let hypothesisPunctuationCount: Int
    public let anchoredEditDistance: Int
    public let errorRate: Double

    public init(
        referencePunctuationCount: Int,
        hypothesisPunctuationCount: Int,
        anchoredEditDistance: Int,
        errorRate: Double
    ) {
        self.referencePunctuationCount = referencePunctuationCount
        self.hypothesisPunctuationCount = hypothesisPunctuationCount
        self.anchoredEditDistance = anchoredEditDistance
        self.errorRate = errorRate
    }

    public var isExact: Bool {
        anchoredEditDistance == 0
    }
}

public enum ScripturePunctuationFidelityMetric {
    public static let maximumInputCharacters = 100_000
    public static let maximumPunctuationMarks = 8_192

    public static func measure(
        reference: String,
        hypothesis: String
    ) throws -> ScripturePunctuationFidelity {
        let referenceAnchors = try anchors(reference, label: "reference")
        let hypothesisAnchors = try anchors(hypothesis, label: "hypothesis")
        let distance = editDistance(referenceAnchors, hypothesisAnchors)
        let denominator = referenceAnchors.count
        let rate =
            denominator == 0
            ? (hypothesisAnchors.isEmpty ? 0 : 1)
            : Double(distance) / Double(denominator)
        return ScripturePunctuationFidelity(
            referencePunctuationCount: referenceAnchors.count,
            hypothesisPunctuationCount: hypothesisAnchors.count,
            anchoredEditDistance: distance,
            errorRate: rate
        )
    }

    private static func anchors(_ text: String, label: String) throws -> [PunctuationAnchor] {
        guard text.count <= maximumInputCharacters else {
            throw ScriptureQualificationError.invalidManifest("\(label) text exceeds metric limit")
        }
        var lexicalOffset = 0
        var result: [PunctuationAnchor] = []
        for character in text {
            if isPunctuation(character) {
                result.append(PunctuationAnchor(mark: character, lexicalOffset: lexicalOffset))
                guard result.count <= maximumPunctuationMarks else {
                    throw ScriptureQualificationError.invalidManifest(
                        "\(label) punctuation exceeds metric limit"
                    )
                }
            } else if !character.isWhitespace {
                lexicalOffset += 1
            }
        }
        return result
    }

    private static func isPunctuation(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.properties.generalCategory {
            case .connectorPunctuation, .dashPunctuation, .openPunctuation,
                .closePunctuation, .initialPunctuation, .finalPunctuation,
                .otherPunctuation:
                true
            default:
                false
            }
        }
    }

    private static func editDistance(
        _ reference: [PunctuationAnchor],
        _ hypothesis: [PunctuationAnchor]
    ) -> Int {
        var previous = Array(0...hypothesis.count)
        for (referenceIndex, referenceAnchor) in reference.enumerated() {
            var current = Array(repeating: 0, count: hypothesis.count + 1)
            current[0] = referenceIndex + 1
            for (hypothesisIndex, hypothesisAnchor) in hypothesis.enumerated() {
                let substitution =
                    previous[hypothesisIndex]
                    + (referenceAnchor == hypothesisAnchor ? 0 : 1)
                current[hypothesisIndex + 1] = min(
                    previous[hypothesisIndex + 1] + 1,
                    current[hypothesisIndex] + 1,
                    substitution
                )
            }
            previous = current
        }
        return previous[hypothesis.count]
    }
}

private struct PunctuationAnchor: Equatable {
    let mark: Character
    let lexicalOffset: Int
}

extension Character {
    fileprivate var isWhitespace: Bool {
        unicodeScalars.allSatisfy { $0.properties.isWhitespace }
    }
}
