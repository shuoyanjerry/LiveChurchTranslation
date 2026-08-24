import Darwin
import Foundation
import TranslationQualificationSupport

struct HyMTQualificationReportSnapshot: Equatable {
    static let maximumByteCount = 64 * 1_024 * 1_024

    let data: Data
    let sha256: String

    static func load(
        workspaceRoot: URL,
        reportFilename: String
    ) throws -> Self {
        try TranslationQualificationReportWriter.validatePrivateFilename(reportFilename)
        return try HyMTQualificationPostflightDirectory.withDescriptor(
            workspaceRoot: workspaceRoot
        ) { directory in
            let descriptor = openat(
                directory,
                reportFilename,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW
            )
            guard descriptor >= 0 else { throw storageFailure }
            defer { _ = close(descriptor) }
            let before = try metadata(descriptor)
            let data = try readAll(descriptor, byteCount: Int(before.st_size))
            let after = try metadata(descriptor)
            guard unchanged(before, after) else { throw storageFailure }
            return Self(
                data: data,
                sha256: TranslationQualificationSHA256.hash(data: data)
            )
        }
    }

    func requireUnchanged(
        workspaceRoot: URL,
        reportFilename: String
    ) throws {
        let current = try Self.load(
            workspaceRoot: workspaceRoot,
            reportFilename: reportFilename
        )
        guard current == self else { throw Self.storageFailure }
    }

    private static func metadata(_ descriptor: Int32) throws -> stat {
        var value = stat()
        guard fstat(descriptor, &value) == 0,
            (value.st_mode & S_IFMT) == S_IFREG,
            value.st_size > 0,
            value.st_size <= maximumByteCount,
            value.st_nlink == 1,
            value.st_uid == geteuid(),
            (value.st_mode & mode_t(0o077)) == 0
        else { throw storageFailure }
        return value
    }

    private static func readAll(_ descriptor: Int32, byteCount: Int) throws -> Data {
        var data = Data(count: byteCount)
        try data.withUnsafeMutableBytes { bytes in
            guard var pointer = bytes.baseAddress else { throw storageFailure }
            var remaining = byteCount
            while remaining > 0 {
                let count = Darwin.read(descriptor, pointer, remaining)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw storageFailure }
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

    private static var storageFailure: TranslationQualificationError {
        .invalidReport("private qualification report is missing, unsafe, or changed")
    }
}
