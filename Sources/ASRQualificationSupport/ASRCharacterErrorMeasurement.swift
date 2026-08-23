/// One normalized character-error measurement.
public struct ASRCharacterErrorMeasurement: Codable, Equatable, Hashable, Sendable {
    public let editCount: Int
    public let referenceCharacterCount: Int
    public let rate: Double

    init(editCount: Int, referenceCharacterCount: Int) {
        self.editCount = editCount
        self.referenceCharacterCount = referenceCharacterCount
        if referenceCharacterCount > 0 {
            rate = Double(editCount) / Double(referenceCharacterCount)
        } else {
            rate = editCount == 0 ? 0 : 1
        }
    }
}
