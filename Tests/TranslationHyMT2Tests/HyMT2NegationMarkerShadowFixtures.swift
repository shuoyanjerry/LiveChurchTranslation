import Foundation

struct HyMT2NegationShadowCueReference: Sendable {
    let text: String
    let occurrence: Int
}

struct HyMT2NegationShadowFixture: Sendable {
    let name: String
    let source: String
    let functionalCues: [HyMT2NegationShadowCueReference]

    func plan(
        encoding: HyMT2NegationShadowEncoding,
        requestID: UUID = negationShadowRequestID
    ) throws -> HyMT2NegationShadowPlan {
        try HyMT2NegationShadowPlan.make(
            source: source,
            functionalCues: try functionalCues.map(sourceCue),
            requestID: requestID,
            encoding: encoding
        )
    }

    private func sourceCue(
        _ reference: HyMT2NegationShadowCueReference
    ) throws -> HyMT2NegationShadowSourceCue {
        let ranges = source.ranges(of: reference.text)
        guard ranges.indices.contains(reference.occurrence) else {
            throw HyMT2NegationShadowFixtureError.missingCue(name)
        }
        return HyMT2NegationShadowSourceCue(
            range: NSRange(ranges[reference.occurrence], in: source),
            text: reference.text
        )
    }
}

enum HyMT2NegationShadowFixtureError: Error {
    case missingCue(String)
}

let negationShadowRequestID =
    UUID(uuidString: "C0DEC0DE-2026-4A22-A000-000000000001") ?? UUID()

enum HyMT2NegationShadowFixtures {
    static let singleNot = fixture("single-not", "教会不隐藏真理。", [("不", 0)])
    static let singleCannot = fixture(
        "single-cannot",
        "门徒不能靠自己结出属灵的果子。",
        [("不能", 0)]
    )
    static let singleNo = fixture("single-no", "没有人能因行为称义。", [("没有", 0)])
    static let singleNever = fixture("single-never", "神从未忘记自己的应许。", [("从未", 0)])
    static let two = fixture(
        "two-independent",
        "没有人能因行为称义，神也从未忘记应许。",
        [("没有", 0), ("从未", 0)]
    )
    static let three = fixture(
        "three-independent",
        "教会不隐藏真理，门徒不能自救，神也没有忘记他们。",
        [("不", 0), ("不能", 0), ("没有", 0)]
    )
    static let mixedNonFunctional = fixture(
        "mixed-nonfunctional",
        "教会不但传讲真理，也不隐藏恩典。",
        [("不", 1)]
    )
    static let nonFunctionalControls = [
        fixture("a-not-a", "你信不信这应许？", []),
        fixture("continuous", "教会不断为这座城祷告。", []),
        fixture("different", "不同的恩赐建造同一个身体。", []),
        fixture("concessive", "不论环境如何，我们仍然祷告。", []),
    ]

    static let lexicalCoverage = [singleNot, singleCannot, singleNo, singleNever]
    static let cardinalityCoverage = [singleNot, two, three]

    private static func fixture(
        _ name: String,
        _ source: String,
        _ cues: [(String, Int)]
    ) -> HyMT2NegationShadowFixture {
        HyMT2NegationShadowFixture(
            name: name,
            source: source,
            functionalCues: cues.map {
                HyMT2NegationShadowCueReference(text: $0.0, occurrence: $0.1)
            }
        )
    }
}

extension String {
    fileprivate func ranges(of needle: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var cursor = startIndex
        while cursor < endIndex {
            guard let range = range(of: needle, range: cursor..<endIndex) else { break }
            result.append(range)
            cursor = range.upperBound
        }
        return result
    }
}
