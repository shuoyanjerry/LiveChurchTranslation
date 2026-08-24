import Foundation
import PersistenceAPI
import TranscriptAPI

extension FileTranscriptStore {
    func scanFailure(
        code: TranscriptRecoveryScanIssue.Code,
        message: String,
        technicalDetail: String? = nil
    ) -> TranscriptRecoveryScan {
        TranscriptRecoveryScan(
            candidates: [],
            issues: [
                TranscriptRecoveryScanIssue(
                    code: code,
                    sessionID: nil,
                    message: message,
                    technicalDetail: technicalDetail
                )
            ],
            didReachLimit: false
        )
    }

    func isSafeSessionDirectory(_ directory: URL) throws -> Bool {
        let values = try directory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    func recoveryManifest(sessionID: UUID) throws -> SessionManifest {
        try requireSafeRegularFile(manifestURL(sessionID), sessionID: sessionID)
        let data = try readBoundedData(
            at: manifestURL(sessionID),
            maximumBytes: min(recoveryLimits.maximumTranscriptBytes, 1_024 * 1_024)
        )
        return try decoder().decode(SessionManifest.self, from: data)
    }

    func readRecoveryEntries(
        sessionID: UUID,
        manifest: SessionManifest
    ) throws -> [TranscriptEntry] {
        try requireSafeRegularFile(jsonLinesURL(sessionID), sessionID: sessionID)
        let data = try readBoundedData(
            at: jsonLinesURL(sessionID),
            maximumBytes: recoveryLimits.maximumTranscriptBytes
        )
        if manifest.storesSourceOnlyEntries {
            return try decodeSourceEntries(data, decoder: lineDecoder())
        }
        return try decodeLegacyOrSourceEntries(data)
    }

    func readBoundedData(at url: URL, maximumBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        var data = Data()
        var readFailure: (any Error)?
        var closeFailure: (any Error)?
        do {
            defer {
                do {
                    try handle.close()
                } catch {
                    closeFailure = error
                }
            }
            do {
                data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
            } catch {
                readFailure = error
            }
        }
        if let readFailure, let closeFailure {
            throw TranscriptRecoveryFileError.readAndCloseFailed(
                read: readFailure.localizedDescription,
                close: closeFailure.localizedDescription
            )
        }
        if let readFailure { throw readFailure }
        if let closeFailure { throw closeFailure }
        guard data.count <= maximumBytes else {
            throw TranscriptRecoveryFileError.byteLimitExceeded(maximumBytes)
        }
        return data
    }

    func recoveredEndDate(
        manifest: SessionManifest,
        entries: [TranscriptEntry]
    ) throws -> Date {
        let now = Date()
        let ceiling = max(now, manifest.startedAt)
        var latest = manifest.startedAt

        if let milliseconds = entries.map(\.endedMilliseconds).filter({ $0 >= 0 }).max() {
            let timelineDate = manifest.startedAt.addingTimeInterval(Double(milliseconds) / 1_000)
            if timelineDate <= ceiling { latest = max(latest, timelineDate) }
        }
        if let createdAt = entries.map(\.createdAt).filter({ $0 <= ceiling }).max() {
            latest = max(latest, createdAt)
        }
        let values = try jsonLinesURL(manifest.id).resourceValues(
            forKeys: [.contentModificationDateKey]
        )
        if let modifiedAt = values.contentModificationDate, modifiedAt <= ceiling {
            latest = max(latest, modifiedAt)
        }
        return Date(timeIntervalSince1970: floor(latest.timeIntervalSince1970))
    }
}

enum TranscriptRecoveryFileError: LocalizedError {
    case byteLimitExceeded(Int)
    case entryLimitExceeded(Int)
    case readAndCloseFailed(read: String, close: String)

    var errorDescription: String? {
        switch self {
        case .byteLimitExceeded(let limit):
            "听抄稿超过自动恢复大小上限（\(limit) 字节）。"
        case .entryLimitExceeded(let limit):
            "听抄稿超过自动恢复段落上限（\(limit) 段）。"
        case .readAndCloseFailed(let read, let close):
            "读取听抄稿失败（\(read)），随后关闭文件也失败（\(close)）。"
        }
    }
}

extension SessionManifest {
    var requiresInterruptionRecovery: Bool {
        integrity == .active || endedAt == nil
    }
}
