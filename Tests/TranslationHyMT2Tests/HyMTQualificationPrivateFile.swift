import Darwin
import Foundation
import TranslationQualificationSupport

struct HyMTQualificationPrivateSnapshot: Equatable {
    let data: Data
    let sha256: String
}

enum HyMTQualificationPrivateFile {
    static func read(
        at url: URL,
        expectedSHA256: String,
        maximumByteCount: Int = 64 * 1_024 * 1_024
    ) throws -> Data {
        let snapshot = try snapshot(at: url, maximumByteCount: maximumByteCount)
        guard snapshot.sha256 == expectedSHA256, isSHA(expectedSHA256) else { throw invalid }
        return snapshot.data
    }

    static func snapshot(
        at url: URL,
        maximumByteCount: Int = 64 * 1_024 * 1_024
    ) throws -> HyMTQualificationPrivateSnapshot {
        let standardized = url.standardizedFileURL
        guard standardized == standardized.resolvingSymlinksInPath() else {
            throw invalid
        }
        let descriptor = open(standardized.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw invalid }
        defer { _ = close(descriptor) }
        let before = try metadata(descriptor, maximumByteCount: maximumByteCount)
        let data = try readAll(descriptor, byteCount: Int(before.st_size))
        let after = try metadata(descriptor, maximumByteCount: maximumByteCount)
        guard unchanged(before, after) else { throw invalid }
        return HyMTQualificationPrivateSnapshot(
            data: data,
            sha256: TranslationQualificationSHA256.hash(data: data)
        )
    }

    private static func metadata(
        _ descriptor: Int32,
        maximumByteCount: Int
    ) throws -> stat {
        var value = stat()
        guard fstat(descriptor, &value) == 0,
            (value.st_mode & S_IFMT) == S_IFREG,
            value.st_size > 0,
            value.st_size <= maximumByteCount,
            value.st_nlink == 1,
            value.st_uid == geteuid(),
            (value.st_mode & mode_t(0o777)) == mode_t(0o600)
        else { throw invalid }
        return value
    }

    private static func readAll(_ descriptor: Int32, byteCount: Int) throws -> Data {
        var data = Data(count: byteCount)
        try data.withUnsafeMutableBytes { bytes in
            guard var pointer = bytes.baseAddress else { throw invalid }
            var remaining = byteCount
            while remaining > 0 {
                let count = Darwin.read(descriptor, pointer, remaining)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw invalid }
                remaining -= count
                pointer = pointer.advanced(by: count)
            }
        }
        return data
    }

    private static func unchanged(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev && lhs.st_ino == rhs.st_ino
            && lhs.st_size == rhs.st_size && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec
            && lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec
            && lhs.st_ctimespec.tv_sec == rhs.st_ctimespec.tv_sec
            && lhs.st_ctimespec.tv_nsec == rhs.st_ctimespec.tv_nsec
    }

    private static func isSHA(_ value: String) -> Bool {
        value.utf8.count == 64
            && value.utf8.allSatisfy {
                (48...57).contains($0) || (97...102).contains($0)
            }
    }

    private static var invalid: TranslationQualificationError {
        .invalidReport("private review input is missing, unsafe, changed, or hash-mismatched")
    }
}
