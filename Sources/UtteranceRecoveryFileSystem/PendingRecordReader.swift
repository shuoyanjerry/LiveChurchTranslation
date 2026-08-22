import Foundation
import UtteranceRecoveryAPI

struct PendingRecordReader {
    let layout: RecoveryLayout
    let limits: UtteranceRecoveryLimits
    let fileManager: FileManager

    func read(_ directory: URL, for sessionID: UUID) throws -> PendingUtteranceRecord {
        let metadataURL = layout.metadataURL(in: directory)
        let audioURL = layout.audioURL(in: directory)
        let metadata = try readMetadata(metadataURL)
        try validateIdentity(metadata, directory: directory, sessionID: sessionID)
        let (decoded, wavByteCount) = try readAudio(audioURL)
        try validateAudio(decoded, byteCount: wavByteCount, metadata: metadata)
        let segment = metadata.makeSegment(samples: decoded.samples)
        do {
            _ = try SpeechSegmentValidator(limits: limits).validate(segment)
        } catch {
            throw RecordReadFailure(reason: .metadataMismatch)
        }
        return PendingUtteranceRecord(id: metadata.id, segment: segment, stagedAt: metadata.stagedAt)
    }

    private func validateIdentity(
        _ metadata: PendingMetadata,
        directory: URL,
        sessionID: UUID
    ) throws {
        guard metadata.schemaVersion == PendingMetadata.currentSchemaVersion else {
            throw RecordReadFailure(reason: .unsupportedSchema)
        }
        guard
            metadata.sessionID == sessionID,
            layout.recordName(metadata.id) == directory.lastPathComponent
        else {
            throw RecordReadFailure(reason: .metadataMismatch)
        }
    }

    private func readAudio(_ url: URL) throws -> (DecodedWAV, Int) {
        let wavData: Data
        do {
            wavData = try boundedData(at: url, maximumBytes: limits.maximumWAVFileBytes)
        } catch let failure as RecordReadFailure {
            throw failure
        } catch {
            throw RecordReadFailure(reason: .orphanedArtifact)
        }
        let decoded: DecodedWAV
        do {
            decoded = try WAVCodec.decode(wavData)
        } catch {
            throw RecordReadFailure(reason: .malformedAudio)
        }
        return (decoded, wavData.count)
    }

    private func validateAudio(
        _ decoded: DecodedWAV,
        byteCount: Int,
        metadata: PendingMetadata
    ) throws {
        guard
            metadata.wavFileBytes == byteCount,
            metadata.sampleCount == decoded.samples.count,
            metadata.sampleRate == Double(decoded.sampleRate)
        else {
            throw RecordReadFailure(reason: .metadataMismatch)
        }
    }

    private func readMetadata(_ url: URL) throws -> PendingMetadata {
        let data: Data
        do {
            data = try boundedData(at: url, maximumBytes: limits.maximumMetadataBytes)
        } catch let failure as RecordReadFailure {
            throw failure
        } catch {
            throw RecordReadFailure(reason: .malformedMetadata)
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(PendingMetadata.self, from: data)
        } catch {
            throw RecordReadFailure(reason: .malformedMetadata)
        }
    }

    private func boundedData(at url: URL, maximumBytes: Int) throws -> Data {
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size >= 0 else {
            throw RecordReadFailure(reason: .orphanedArtifact)
        }
        guard size <= maximumBytes else {
            throw RecordReadFailure(reason: .oversizedArtifact)
        }
        return try Data(contentsOf: url, options: [.mappedIfSafe])
    }
}

struct RecordReadFailure: Error {
    let reason: UtteranceQuarantineReason
}
