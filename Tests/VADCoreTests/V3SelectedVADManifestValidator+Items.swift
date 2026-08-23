import Foundation

extension V3SelectedVADManifestValidator {
    static func validateItems(_ values: [V3SelectedVADManifestItem]) throws {
        guard values.count == V3SelectedVADPolicy.logicalItemCount,
            Set(values.map(\.itemID)).count == values.count
        else { throw V3SelectedVADError.invalidManifest("items") }
        var trackCount = 0
        var sampleCount: Int64 = 0
        for item in values {
            guard item.trackCount == item.tracks.count, !item.concatenated,
                item.tracks.map(\.ordinal) == Array(1...item.trackCount)
            else { throw V3SelectedVADError.invalidManifest("item tracks") }
            for track in item.tracks {
                try validateTrack(track, itemID: item.itemID)
                trackCount += 1
                sampleCount += track.exactSampleFrames
            }
        }
        guard trackCount == V3SelectedVADPolicy.trackCount,
            sampleCount == V3SelectedVADPolicy.sampleFrames
        else { throw V3SelectedVADError.invalidManifest("track totals") }
    }

    private static func validateTrack(
        _ value: V3SelectedVADManifestTrack,
        itemID: String
    ) throws {
        guard value.itemID == itemID, isDigest(value.convertedWAVSHA256),
            value.convertedWAVByteSize > 44, value.exactSampleFrames > 0,
            value.pcmDataByteSize == value.exactSampleFrames * 2,
            close(value.exactDurationSeconds, Double(value.exactSampleFrames) / 16_000),
            value.resetStateBeforeTrack, value.emitEndOfStreamAfterTrack,
            !value.allowContinuationFromPreviousTrack,
            isSafeRelativeWAVPath(value.relativeWAVPath)
        else { throw V3SelectedVADError.invalidManifest("track") }
    }

    static func isDigest(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isNumber || ("a"..."f").contains(String($0)) }
    }

    private static func isSafeRelativeWAVPath(_ value: String) -> Bool {
        let components = NSString(string: value).pathComponents
        return !value.hasPrefix("/") && !components.contains("..")
            && value.hasSuffix(".wav") && components.count >= 2
    }
}
