import Darwin
import Foundation

enum CandidatePausePrivateWriter {
    static func write(
        _ data: Data,
        workspaceRoot: URL,
        output: URL
    ) throws -> URL {
        let rootURL = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL
        let filename = output.lastPathComponent
        try validate(filename: filename, output: output, root: rootURL)
        let root = open(rootURL.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard root >= 0 else { throw CandidatePauseBenchmarkError.storageFailure }
        defer { _ = close(root) }
        let artifacts = try childDirectory(".artifacts", parent: root)
        defer { _ = close(artifacts) }
        let reports = try childDirectory(
            "vad-benchmarks",
            parent: artifacts,
            requirePrivateMode: true
        )
        defer { _ = close(reports) }
        try atomicWrite(data, filename: filename, directory: reports)
        try requirePrivateRegularFile(filename, directory: reports)
        return
            rootURL
            .appendingPathComponent(".artifacts/vad-benchmarks", isDirectory: true)
            .appendingPathComponent(filename)
    }

    private static func validate(filename: String, output: URL, root: URL) throws {
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
        )
        let expected =
            root
            .appendingPathComponent(".artifacts/vad-benchmarks", isDirectory: true)
            .appendingPathComponent(filename)
            .standardizedFileURL
        guard output.standardizedFileURL.path == expected.path,
            filename.count <= 128, filename.hasSuffix(".json"),
            filename.first?.isLetter == true || filename.first?.isNumber == true,
            !filename.contains(".."), filename.unicodeScalars.allSatisfy(allowed.contains)
        else { throw CandidatePauseBenchmarkError.unsafeOutput }
    }

    private static func childDirectory(
        _ name: String,
        parent: Int32,
        requirePrivateMode: Bool = false
    ) throws -> Int32 {
        if mkdirat(parent, name, mode_t(0o700)) != 0, errno != EEXIST {
            throw CandidatePauseBenchmarkError.storageFailure
        }
        let descriptor = openat(parent, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw CandidatePauseBenchmarkError.storageFailure }
        if requirePrivateMode {
            guard fchmod(descriptor, mode_t(0o700)) == 0 else {
                _ = close(descriptor)
                throw CandidatePauseBenchmarkError.storageFailure
            }
        }
        return descriptor
    }

    private static func atomicWrite(
        _ data: Data,
        filename: String,
        directory: Int32
    ) throws {
        try requireAbsent(filename, directory: directory)
        let temporary = ".candidate-pause-\(UUID().uuidString).tmp"
        let descriptor = openat(
            directory,
            temporary,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard descriptor >= 0 else { throw CandidatePauseBenchmarkError.storageFailure }
        var keepTemporary = true
        defer {
            _ = close(descriptor)
            if keepTemporary { _ = unlinkat(directory, temporary, 0) }
        }
        guard fchmod(descriptor, mode_t(0o600)) == 0 else {
            throw CandidatePauseBenchmarkError.storageFailure
        }
        try writeAll(data, descriptor: descriptor)
        guard fsync(descriptor) == 0,
            renameatx_np(directory, temporary, directory, filename, UInt32(RENAME_EXCL)) == 0
        else { throw CandidatePauseBenchmarkError.storageFailure }
        keepTemporary = false
        guard fsync(directory) == 0 else { throw CandidatePauseBenchmarkError.storageFailure }
    }

    private static func requireAbsent(_ filename: String, directory: Int32) throws {
        var value = stat()
        let result = fstatat(directory, filename, &value, AT_SYMLINK_NOFOLLOW)
        if result == 0 { throw CandidatePauseBenchmarkError.storageFailure }
        guard errno == ENOENT else { throw CandidatePauseBenchmarkError.storageFailure }
    }

    private static func requirePrivateRegularFile(
        _ filename: String,
        directory: Int32
    ) throws {
        var value = stat()
        guard fstatat(directory, filename, &value, AT_SYMLINK_NOFOLLOW) == 0,
            (value.st_mode & S_IFMT) == S_IFREG,
            (value.st_mode & mode_t(0o777)) == mode_t(0o600)
        else { throw CandidatePauseBenchmarkError.storageFailure }
    }

    private static func writeAll(_ data: Data, descriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            guard var pointer = bytes.baseAddress else { return }
            var remaining = bytes.count
            while remaining > 0 {
                let count = Darwin.write(descriptor, pointer, remaining)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw CandidatePauseBenchmarkError.storageFailure }
                remaining -= count
                pointer = pointer.advanced(by: count)
            }
        }
    }
}
