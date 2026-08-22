public struct ProjectionConfiguration: Equatable, Sendable {
    public let maximumSnapshotEntries: Int
    public let peerQueueCapacity: Int
    public let maximumTextCharacters: Int
    public let maximumSnapshotUTF8Bytes: Int

    public init(
        maximumSnapshotEntries: Int = 10_000,
        peerQueueCapacity: Int = 256,
        maximumTextCharacters: Int = 20_000,
        maximumSnapshotUTF8Bytes: Int = 2_000_000
    ) {
        self.maximumSnapshotEntries = min(max(maximumSnapshotEntries, 1), 50_000)
        self.peerQueueCapacity = min(max(peerQueueCapacity, 2), 2_048)
        self.maximumTextCharacters = min(max(maximumTextCharacters, 256), 100_000)
        self.maximumSnapshotUTF8Bytes = min(max(maximumSnapshotUTF8Bytes, 65_536), 8_000_000)
    }
}

public enum ProjectionError: Error, Equatable, Sendable {
    case textTooLarge
}
