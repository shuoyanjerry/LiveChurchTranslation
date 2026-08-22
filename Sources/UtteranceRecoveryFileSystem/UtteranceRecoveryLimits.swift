import UtteranceRecoveryAPI

/// Resource limits applied before allocating or persisting recovery audio.
public struct UtteranceRecoveryLimits: Sendable, Equatable {
    public static let sermonDefault = UtteranceRecoveryLimits(
        maximumSampleCount: 960_000,
        maximumWAVFileBytes: 3_840_044,
        maximumMetadataBytes: 16_384,
        minimumSampleRate: 8_000,
        maximumSampleRate: 48_000,
        maximumRootEntryCount: 1_024,
        maximumSessionCount: 1_000,
        maximumEntriesPerSession: 2_048,
        maximumTotalRecoveryCount: 10_000
    )

    public let maximumSampleCount: Int
    public let maximumWAVFileBytes: Int
    public let maximumMetadataBytes: Int
    public let minimumSampleRate: UInt32
    public let maximumSampleRate: UInt32
    public let maximumRootEntryCount: Int
    public let maximumSessionCount: Int
    public let maximumEntriesPerSession: Int
    public let maximumTotalRecoveryCount: Int

    public init(
        maximumSampleCount: Int,
        maximumWAVFileBytes: Int,
        maximumMetadataBytes: Int = 16_384,
        minimumSampleRate: UInt32 = 8_000,
        maximumSampleRate: UInt32 = 48_000,
        maximumRootEntryCount: Int = 1_024,
        maximumSessionCount: Int = 1_000,
        maximumEntriesPerSession: Int = 2_048,
        maximumTotalRecoveryCount: Int = 10_000
    ) {
        self.maximumSampleCount = maximumSampleCount
        self.maximumWAVFileBytes = maximumWAVFileBytes
        self.maximumMetadataBytes = maximumMetadataBytes
        self.minimumSampleRate = minimumSampleRate
        self.maximumSampleRate = maximumSampleRate
        self.maximumRootEntryCount = maximumRootEntryCount
        self.maximumSessionCount = maximumSessionCount
        self.maximumEntriesPerSession = maximumEntriesPerSession
        self.maximumTotalRecoveryCount = maximumTotalRecoveryCount
    }

    func validate() throws {
        let maximumEncodableSamples = (Int(UInt32.max) - WAVFormat.headerByteCount) / 4
        guard maximumSampleCount > 0, maximumSampleCount <= maximumEncodableSamples else {
            throw UtteranceRecoveryError.invalidConfiguration("maximumSampleCount")
        }
        guard
            maximumWAVFileBytes >= WAVFormat.headerByteCount,
            maximumWAVFileBytes <= Int(UInt32.max)
        else {
            throw UtteranceRecoveryError.invalidConfiguration("maximumWAVFileBytes")
        }
        guard maximumMetadataBytes > 0 else {
            throw UtteranceRecoveryError.invalidConfiguration("maximumMetadataBytes")
        }
        guard minimumSampleRate > 0, minimumSampleRate <= maximumSampleRate else {
            throw UtteranceRecoveryError.invalidConfiguration("sampleRateRange")
        }
        guard
            maximumRootEntryCount > 0,
            maximumSessionCount > 0,
            maximumSessionCount <= maximumRootEntryCount,
            maximumEntriesPerSession > 0,
            maximumTotalRecoveryCount > 0
        else {
            throw UtteranceRecoveryError.invalidConfiguration("recoveryScanLimits")
        }
    }
}
