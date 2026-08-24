import Darwin
import Foundation
import TranslationQualificationSupport

enum HyMTQualificationPostflightWriter {
    @discardableResult
    static func writePrivate(
        _ data: Data,
        workspaceRoot: URL,
        filename: String
    ) throws -> URL {
        try TranslationQualificationReportWriter.validatePrivateFilename(filename)
        try HyMTQualificationPostflightDirectory.withDescriptor(
            workspaceRoot: workspaceRoot
        ) { try write(data, filename: filename, directory: $0) }
        return workspaceRoot.resolvingSymlinksInPath().standardizedFileURL
            .appendingPathComponent(".artifacts/translation-qualification", isDirectory: true)
            .appendingPathComponent(filename, isDirectory: false)
    }

    @discardableResult
    static func writePrivate(
        _ attestation: HyMTQualificationPostflightAttestation,
        workspaceRoot: URL,
        reportFilename: String
    ) throws -> URL {
        guard attestation.schemaVersion == HyMTQualificationPostflightAttestation.currentSchemaVersion,
            attestation.postflightVerified
        else {
            throw TranslationQualificationError.invalidReport(
                "postflight attestation is not verified"
            )
        }
        let filename = try HyMTQualificationPostflightDirectory.sidecarFilename(
            for: reportFilename
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(attestation)
        return try writePrivate(data, workspaceRoot: workspaceRoot, filename: filename)
    }

    private static func write(_ data: Data, filename: String, directory: Int32) throws {
        try requireAbsent(filename, directory: directory)
        let temporary = ".postflight-\(UUID().uuidString).tmp"
        let descriptor = openat(
            directory,
            temporary,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard descriptor >= 0 else { throw storageFailure }
        var keepTemporary = true
        defer {
            _ = close(descriptor)
            if keepTemporary { _ = unlinkat(directory, temporary, 0) }
        }
        guard fchmod(descriptor, mode_t(0o600)) == 0 else { throw storageFailure }
        try writeAll(data, descriptor: descriptor)
        try requirePrivateRegularFile(descriptor)
        guard fsync(descriptor) == 0 else { throw storageFailure }
        guard
            renameatx_np(
                directory,
                temporary,
                directory,
                filename,
                UInt32(RENAME_EXCL)
            ) == 0
        else { throw storageFailure }
        keepTemporary = false
        guard fsync(directory) == 0 else { throw storageFailure }
    }

    private static func requireAbsent(_ filename: String, directory: Int32) throws {
        var value = stat()
        let result = fstatat(directory, filename, &value, AT_SYMLINK_NOFOLLOW)
        if result == 0 { throw storageFailure }
        guard errno == ENOENT else { throw storageFailure }
    }

    private static func requirePrivateRegularFile(_ descriptor: Int32) throws {
        var value = stat()
        guard fstat(descriptor, &value) == 0,
            (value.st_mode & S_IFMT) == S_IFREG,
            (value.st_mode & mode_t(0o777)) == mode_t(0o600)
        else { throw storageFailure }
    }

    private static func writeAll(_ data: Data, descriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            guard var pointer = bytes.baseAddress else { return }
            var remaining = bytes.count
            while remaining > 0 {
                let count = Darwin.write(descriptor, pointer, remaining)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw storageFailure }
                remaining -= count
                pointer = pointer.advanced(by: count)
            }
        }
    }

    private static var storageFailure: TranslationQualificationError {
        HyMTQualificationPostflightDirectory.storageFailure
    }
}
