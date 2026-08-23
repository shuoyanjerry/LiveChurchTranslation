import Foundation
import RecordingAPI

extension FileSessionRecordingStore {
    public func repairInterruptedRecording(
        sessionID: UUID
    ) async throws -> SessionRecordingMetadata? {
        guard active[sessionID] == nil else {
            throw RecordingStoreError.sessionAlreadyActive(sessionID)
        }
        let layout = RecordingFileLayout(root: root, sessionID: sessionID)
        let publishedRecordingExists =
            fileManager.fileExists(atPath: layout.finalURL.path)
            && fileManager.fileExists(atPath: layout.activeMarkerURL.path)
        if publishedRecordingExists {
            return try recoverPublishedRecording(sessionID: sessionID, layout: layout)
        }
        guard fileManager.fileExists(atPath: layout.partialURL.path) else {
            try layout.clearActiveMarker(fileManager: fileManager)
            return nil
        }
        do {
            try layout.prepareDirectories(fileManager: fileManager)
            return try repairPartial(sessionID: sessionID, layout: layout)
        } catch let error as CAFHeaderError {
            throw RecordingStoreError.malformedPartialRecording(
                sessionID: sessionID,
                reason: error.reason
            )
        } catch {
            throw storageError("repair interrupted recording", error)
        }
    }

    private func repairPartial(
        sessionID: UUID,
        layout: RecordingFileLayout
    ) throws -> SessionRecordingMetadata {
        let handle = try FileHandle(forUpdating: layout.partialURL)
        var didClose = false
        defer {
            if !didClose { try? handle.close() }
        }
        let inspection = try inspectPartial(handle)
        let repairedDataBytes = inspection.repairedDataBytes
        guard repairedDataBytes > 0 else { throw RecordingStoreError.noAudio(sessionID) }
        if repairedDataBytes != inspection.physicalDataBytes {
            try handle.truncate(atOffset: PCM16CAF.headerByteCount + repairedDataBytes)
        }
        try PCM16CAF.finalizeDataChunk(
            in: handle,
            dataByteCount: repairedDataBytes
        )
        try handle.synchronize()
        try handle.close()
        didClose = true
        try layout.enforcePrivateFile(fileManager: fileManager)
        try layout.publish()
        try layout.synchronizeDirectory()
        try layout.clearActiveMarker(fileManager: fileManager)
        return metadata(
            sessionID: sessionID,
            layout: layout,
            format: inspection.format,
            dataByteCount: repairedDataBytes,
            recovered: true
        )
    }

    private func inspectPartial(_ handle: FileHandle) throws -> PartialRecordingInspection {
        let fileByteCount = try handle.seekToEnd()
        guard fileByteCount >= PCM16CAF.headerByteCount else {
            throw CAFHeaderError("file is shorter than its CAF header")
        }
        try handle.seek(toOffset: 0)
        let header = try handle.read(upToCount: Int(PCM16CAF.headerByteCount)) ?? Data()
        let format = try PCM16CAF.readFormat(from: header)
        let blockAlign = UInt64(format.channelCount * MemoryLayout<Int16>.size)
        let physicalDataBytes = fileByteCount - PCM16CAF.headerByteCount
        let maximum = limits.maximumDataBytes(blockAlign: blockAlign)
        guard physicalDataBytes <= maximum else {
            throw RecordingStoreError.dataLimitExceeded(
                attemptedBytes: physicalDataBytes,
                maximumBytes: maximum
            )
        }
        return PartialRecordingInspection(
            format: format,
            physicalDataBytes: physicalDataBytes,
            repairedDataBytes: physicalDataBytes - (physicalDataBytes % blockAlign)
        )
    }

    private func recoverPublishedRecording(
        sessionID: UUID,
        layout: RecordingFileLayout
    ) throws -> SessionRecordingMetadata {
        let handle = try FileHandle(forReadingFrom: layout.finalURL)
        defer { try? handle.close() }
        let fileByteCount = try handle.seekToEnd()
        guard fileByteCount >= PCM16CAF.headerByteCount else {
            throw CAFHeaderError("published file is shorter than its CAF header")
        }
        try handle.seek(toOffset: 0)
        let header = try handle.read(upToCount: Int(PCM16CAF.headerByteCount)) ?? Data()
        let format = try PCM16CAF.readFormat(from: header)
        let blockAlign = UInt64(format.channelCount * MemoryLayout<Int16>.size)
        let dataByteCount = fileByteCount - PCM16CAF.headerByteCount
        guard dataByteCount > 0, dataByteCount.isMultiple(of: blockAlign) else {
            throw CAFHeaderError("published file contains incomplete audio frames")
        }
        try layout.clearActiveMarker(fileManager: fileManager)
        return metadata(
            sessionID: sessionID,
            layout: layout,
            format: format,
            dataByteCount: dataByteCount,
            recovered: true
        )
    }
}

private struct PartialRecordingInspection {
    let format: RecordingFormat
    let physicalDataBytes: UInt64
    let repairedDataBytes: UInt64
}
