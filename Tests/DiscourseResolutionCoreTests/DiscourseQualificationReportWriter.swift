import Darwin
import Foundation
import TranslationQualificationSupport

struct DiscourseQualificationReportWriter {
    let workspaceRoot: URL
    let filename: String

    func write(
        _ report: DiscourseQualificationReport,
        corpus: TranslationQualificationCorpus
    ) throws -> URL {
        try TranslationQualificationReportWriter.validatePrivateFilename(filename)
        let data = try encoded(report)
        try DiscourseQualificationPrivacyGuard.validate(data, corpus: corpus)
        return try store(data)
    }

    private func encoded(_ report: DiscourseQualificationReport) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(report)
        } catch {
            throw storageError
        }
    }

    private func store(_ data: Data) throws -> URL {
        let canonicalRoot = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL
        let root = try openDirectory(at: canonicalRoot.path)
        defer { _ = close(root) }
        let artifacts = try childDirectory(".artifacts", parent: root)
        defer { _ = close(artifacts) }
        let reports = try childDirectory("discourse-qualification", parent: artifacts)
        defer { _ = close(reports) }
        try rejectDestinationSymlink(in: reports)
        try atomicWrite(data, directory: reports)
        return
            canonicalRoot
            .appendingPathComponent(".artifacts/discourse-qualification", isDirectory: true)
            .appendingPathComponent(filename, isDirectory: false)
    }

    private func openDirectory(at path: String) throws -> Int32 {
        let descriptor = Darwin.open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw storageError }
        return descriptor
    }

    private func childDirectory(_ name: String, parent: Int32) throws -> Int32 {
        if mkdirat(parent, name, mode_t(0o700)) != 0, errno != EEXIST {
            throw storageError
        }
        let descriptor = openat(parent, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw storageError }
        return descriptor
    }

    private func rejectDestinationSymlink(in directory: Int32) throws {
        var metadata = stat()
        let result = fstatat(directory, filename, &metadata, AT_SYMLINK_NOFOLLOW)
        if result == 0, (metadata.st_mode & S_IFMT) == S_IFLNK {
            throw TranslationQualificationError.unsafePath(
                "discourse qualification destination is unsafe"
            )
        }
        if result != 0, errno != ENOENT { throw storageError }
    }

    private func atomicWrite(_ data: Data, directory: Int32) throws {
        let temporary = ".discourse-qualification-\(UUID().uuidString).tmp"
        let descriptor = openat(
            directory,
            temporary,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard descriptor >= 0 else { throw storageError }
        var keepTemporary = true
        defer {
            _ = close(descriptor)
            if keepTemporary { _ = unlinkat(directory, temporary, 0) }
        }
        try writeAll(data, to: descriptor)
        guard fsync(descriptor) == 0 else { throw storageError }
        guard renameat(directory, temporary, directory, filename) == 0 else {
            throw storageError
        }
        keepTemporary = false
        guard fsync(directory) == 0 else { throw storageError }
    }

    private func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            guard var pointer = bytes.baseAddress else { return }
            var remaining = bytes.count
            while remaining > 0 {
                let count = Darwin.write(descriptor, pointer, remaining)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw storageError }
                remaining -= count
                pointer = pointer.advanced(by: count)
            }
        }
    }

    private var storageError: TranslationQualificationError {
        .writeFailed("discourse qualification report storage failed")
    }
}
