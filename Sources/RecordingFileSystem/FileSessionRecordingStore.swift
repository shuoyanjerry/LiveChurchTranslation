import AudioCaptureAPI
import Foundation
import RecordingAPI

public actor FileSessionRecordingStore: SessionRecordingStore {
    let root: URL
    let limits: RecordingFileLimits
    let fileManager: FileManager
    var active: [UUID: ActiveRecording] = [:]

    public init(
        root: URL,
        limits: RecordingFileLimits = RecordingFileLimits(),
        fileManager: FileManager = .default
    ) throws {
        try limits.validate()
        self.root = root
        self.limits = limits
        self.fileManager = fileManager
    }

    deinit {
        for recording in active.values {
            try? recording.handle?.close()
        }
    }

    public func begin(sessionID: UUID) async throws {
        guard active[sessionID] == nil else {
            throw RecordingStoreError.sessionAlreadyActive(sessionID)
        }
        let layout = RecordingFileLayout(root: root, sessionID: sessionID)
        do {
            try layout.prepareDirectories(fileManager: fileManager)
            guard !fileManager.fileExists(atPath: layout.finalURL.path) else {
                throw RecordingStoreError.recordingAlreadyExists(sessionID)
            }
            guard !fileManager.fileExists(atPath: layout.partialURL.path) else {
                throw RecordingStoreError.interruptedRecordingExists(sessionID)
            }
            guard !fileManager.fileExists(atPath: layout.activeMarkerURL.path) else {
                throw RecordingStoreError.interruptedRecordingExists(sessionID)
            }
            try layout.createActiveMarker(fileManager: fileManager)
            active[sessionID] = ActiveRecording()
        } catch {
            throw storageError("begin", error)
        }
    }

    public func append(_ frame: AudioFrame, to sessionID: UUID) async throws {
        guard var recording = active[sessionID] else {
            throw RecordingStoreError.sessionNotActive(sessionID)
        }
        let format = try RecordingFrameValidator.validate(frame)
        if let expected = recording.format, expected != format {
            throw RecordingStoreError.formatChanged(expected: expected, actual: format)
        }
        let blockAlign = UInt64(format.channelCount * MemoryLayout<Int16>.size)
        let incomingBytes = UInt64(frame.samples.count) * UInt64(MemoryLayout<Int16>.size)
        let attempted = recording.dataByteCount.addingReportingOverflow(incomingBytes)
        let maximum = limits.maximumDataBytes(blockAlign: blockAlign)
        guard !attempted.overflow, attempted.partialValue <= maximum else {
            throw RecordingStoreError.dataLimitExceeded(
                attemptedBytes: attempted.partialValue,
                maximumBytes: maximum
            )
        }
        let layout = RecordingFileLayout(root: root, sessionID: sessionID)
        do {
            if recording.handle == nil {
                recording.handle = try layout.createPartial(
                    header: PCM16CAF.header(format: format, dataByteCount: nil),
                    fileManager: fileManager
                )
                recording.format = format
            }
            try recording.handle?.write(contentsOf: PCM16Encoder.encode(frame.samples))
            recording.dataByteCount = attempted.partialValue
            active[sessionID] = recording
        } catch {
            try? recording.handle?.close()
            active.removeValue(forKey: sessionID)
            throw storageError("append", error)
        }
    }
}

extension FileSessionRecordingStore {
    public func finish(sessionID: UUID) async throws -> SessionRecordingMetadata {
        guard let recording = active.removeValue(forKey: sessionID) else {
            throw RecordingStoreError.sessionNotActive(sessionID)
        }
        let layout = RecordingFileLayout(root: root, sessionID: sessionID)
        guard let format = recording.format, let handle = recording.handle else {
            do {
                try layout.clearActiveMarker(fileManager: fileManager)
            } catch {
                throw storageError("finish empty recording", error)
            }
            throw RecordingStoreError.noAudio(sessionID)
        }
        do {
            try PCM16CAF.finalizeDataChunk(
                in: handle,
                dataByteCount: recording.dataByteCount
            )
            try handle.synchronize()
            try handle.close()
            try layout.enforcePrivateFile(fileManager: fileManager)
            try layout.publish()
            try layout.synchronizeDirectory()
            try layout.clearActiveMarker(fileManager: fileManager)
            return metadata(
                sessionID: sessionID,
                layout: layout,
                format: format,
                dataByteCount: recording.dataByteCount,
                recovered: false
            )
        } catch {
            try? handle.close()
            throw storageError("finish", error)
        }
    }

    public func discard(sessionID: UUID) async throws {
        let recording = active.removeValue(forKey: sessionID)
        let layout = RecordingFileLayout(root: root, sessionID: sessionID)
        var failure: (any Error)?
        do { try recording?.handle?.close() } catch { failure = error }
        do {
            if fileManager.fileExists(atPath: layout.partialURL.path) {
                try fileManager.removeItem(at: layout.partialURL)
                try layout.synchronizeDirectory()
            }
            try layout.clearActiveMarker(fileManager: fileManager)
        } catch {
            if failure == nil { failure = error }
        }
        if let failure { throw storageError("discard", failure) }
    }

    func metadata(
        sessionID: UUID,
        layout: RecordingFileLayout,
        format: RecordingFormat,
        dataByteCount: UInt64,
        recovered: Bool
    ) -> SessionRecordingMetadata {
        let blockAlign = UInt64(format.channelCount * MemoryLayout<Int16>.size)
        return SessionRecordingMetadata(
            sessionID: sessionID,
            fileURL: layout.finalURL,
            format: format,
            frameCount: dataByteCount / blockAlign,
            audioDataByteCount: dataByteCount,
            recoveredFromInterruption: recovered
        )
    }

    func storageError(_ operation: String, _ error: Error) -> RecordingStoreError {
        if let error = error as? RecordingStoreError { return error }
        return .fileSystem(operation: operation, reason: error.localizedDescription)
    }
}

struct ActiveRecording {
    var format: RecordingFormat?
    var handle: FileHandle?
    var dataByteCount: UInt64 = 0
}
