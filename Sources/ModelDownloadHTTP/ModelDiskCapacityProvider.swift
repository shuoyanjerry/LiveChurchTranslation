import Foundation

protocol ModelDiskCapacityProviding: Sendable {
    func availableCapacity(at directory: URL) throws -> Int64
}

struct VolumeModelDiskCapacityProvider: ModelDiskCapacityProviding {
    func availableCapacity(at directory: URL) throws -> Int64 {
        let values = try directory.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ])
        if let capacity = values.volumeAvailableCapacityForImportantUsage {
            return max(0, capacity)
        }
        if let capacity = values.volumeAvailableCapacity {
            return Int64(max(0, capacity))
        }
        throw CocoaError(.fileReadUnknown)
    }
}
