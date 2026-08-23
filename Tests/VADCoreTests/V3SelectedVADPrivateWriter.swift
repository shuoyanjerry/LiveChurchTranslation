import Darwin
import Foundation

enum V3SelectedVADPrivateWriter {
    static func write(
        _ data: Data,
        inputs: V3SelectedVADInputs
    ) throws -> V3SelectedVADFingerprint {
        guard let outputURL = inputs.outputURL else { throw V3SelectedVADError.missingOutput }
        let workspace = inputs.workspaceRoot
        let root = open(workspace.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard root >= 0 else { throw V3SelectedVADError.storageFailure }
        defer { _ = close(root) }
        let artifacts = try childDirectory(".artifacts", parent: root)
        defer { _ = close(artifacts) }
        let reports = try childDirectory("v3-selected-vad", parent: artifacts)
        defer { _ = close(reports) }
        try atomicWrite(data, filename: outputURL.lastPathComponent, directory: reports)
        try requirePrivateFile(outputURL.lastPathComponent, directory: reports)
        return try V3SelectedVADHashing.fingerprint(outputURL)
    }

    private static func childDirectory(_ name: String, parent: Int32) throws -> Int32 {
        if mkdirat(parent, name, mode_t(0o700)) != 0, errno != EEXIST {
            throw V3SelectedVADError.storageFailure
        }
        let descriptor = openat(parent, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw V3SelectedVADError.storageFailure }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
            (metadata.st_mode & S_IFMT) == S_IFDIR,
            (metadata.st_mode & mode_t(0o777)) == mode_t(0o700)
        else {
            _ = close(descriptor)
            throw V3SelectedVADError.storageFailure
        }
        return descriptor
    }

    private static func atomicWrite(
        _ data: Data,
        filename: String,
        directory: Int32
    ) throws {
        try requireAbsent(filename, directory: directory)
        let temporary = ".v3-selected-vad-\(UUID().uuidString).tmp"
        let descriptor = openat(
            directory,
            temporary,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard descriptor >= 0 else { throw V3SelectedVADError.storageFailure }
        var keepTemporary = true
        defer {
            _ = close(descriptor)
            if keepTemporary { _ = unlinkat(directory, temporary, 0) }
        }
        guard fchmod(descriptor, mode_t(0o600)) == 0 else {
            throw V3SelectedVADError.storageFailure
        }
        try writeAll(data, descriptor: descriptor)
        guard fsync(descriptor) == 0,
            renameatx_np(directory, temporary, directory, filename, UInt32(RENAME_EXCL)) == 0
        else { throw V3SelectedVADError.storageFailure }
        keepTemporary = false
        guard fsync(directory) == 0 else { throw V3SelectedVADError.storageFailure }
    }

    private static func requireAbsent(_ filename: String, directory: Int32) throws {
        var value = stat()
        let result = fstatat(directory, filename, &value, AT_SYMLINK_NOFOLLOW)
        if result == 0 { throw V3SelectedVADError.storageFailure }
        guard errno == ENOENT else { throw V3SelectedVADError.storageFailure }
    }

    private static func requirePrivateFile(_ filename: String, directory: Int32) throws {
        var value = stat()
        guard fstatat(directory, filename, &value, AT_SYMLINK_NOFOLLOW) == 0,
            (value.st_mode & S_IFMT) == S_IFREG,
            (value.st_mode & mode_t(0o777)) == mode_t(0o600)
        else { throw V3SelectedVADError.storageFailure }
    }

    private static func writeAll(_ data: Data, descriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            guard var pointer = bytes.baseAddress else { return }
            var remaining = bytes.count
            while remaining > 0 {
                let count = Darwin.write(descriptor, pointer, remaining)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw V3SelectedVADError.storageFailure }
                remaining -= count
                pointer = pointer.advanced(by: count)
            }
        }
    }
}
