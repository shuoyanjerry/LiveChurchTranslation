/// One normalized word-error measurement.
public struct ASRWordErrorMeasurement: Codable, Equatable, Hashable, Sendable {
    public let editCount: Int
    public let referenceWordCount: Int
    public let rate: Double

    init(editCount: Int, referenceWordCount: Int) {
        self.editCount = editCount
        self.referenceWordCount = referenceWordCount
        if referenceWordCount > 0 {
            rate = Double(editCount) / Double(referenceWordCount)
        } else {
            rate = editCount == 0 ? 0 : 1
        }
    }
}

enum ASRWordAligner {
    static func editCount(reference: [String], hypothesis: [String]) -> Int {
        var previous = Array(0...hypothesis.count)
        for (referenceOffset, referenceWord) in reference.enumerated() {
            var current = Array(repeating: 0, count: hypothesis.count + 1)
            current[0] = referenceOffset + 1
            for (hypothesisOffset, hypothesisWord) in hypothesis.enumerated() {
                current[hypothesisOffset + 1] = min(
                    previous[hypothesisOffset]
                        + (referenceWord == hypothesisWord ? 0 : 1),
                    previous[hypothesisOffset + 1] + 1,
                    current[hypothesisOffset] + 1
                )
            }
            previous = current
        }
        return previous[hypothesis.count]
    }
}
