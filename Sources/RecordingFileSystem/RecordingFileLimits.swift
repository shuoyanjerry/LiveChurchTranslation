import RecordingAPI

public struct RecordingFileLimits: Equatable, Sendable {
    public static let cafMaximumDataBytes = UInt64(Int64.max) - 68

    public let maximumDataBytes: UInt64

    public init(maximumDataBytes: UInt64 = cafMaximumDataBytes) {
        self.maximumDataBytes = maximumDataBytes
    }

    func validate() throws {
        guard maximumDataBytes > 0 else {
            throw RecordingStoreError.invalidConfiguration("maximumDataBytes must be positive")
        }
        guard maximumDataBytes <= Self.cafMaximumDataBytes else {
            throw RecordingStoreError.invalidConfiguration(
                "maximumDataBytes exceeds the CAF signed 64-bit file boundary"
            )
        }
    }

    func maximumDataBytes(blockAlign: UInt64) -> UInt64 {
        maximumDataBytes - (maximumDataBytes % blockAlign)
    }
}
