import Darwin
import Foundation

struct ScriptureQualificationReportStorage {
    let workspaceRoot: URL
    let reportURL: URL

    func write(_ data: Data) throws {
        let rootURL = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL
        let expectedDirectory = rootURL.appendingPathComponent(
            ".artifacts/scripture-qualification-reports",
            isDirectory: true
        )
        guard
            reportURL.standardizedFileURL.deletingLastPathComponent().path
                == expectedDirectory.path,
            validFilename(reportURL.lastPathComponent)
        else { throw ScriptureModelQualificationError.reportWriteFailed }
        let root = try openDirectory(rootURL.path)
        defer { _ = close(root) }
        let artifacts = try childDirectory(".artifacts", parent: root, ownerOnly: false)
        defer { _ = close(artifacts) }
        let reports = try childDirectory(
            "scripture-qualification-reports",
            parent: artifacts,
            ownerOnly: true
        )
        defer { _ = close(reports) }
        try atomicWrite(data, filename: reportURL.lastPathComponent, directory: reports)
    }

    private func openDirectory(_ path: String) throws -> Int32 {
        let descriptor = Darwin.open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw ScriptureModelQualificationError.reportWriteFailed }
        return descriptor
    }

    private func childDirectory(
        _ name: String,
        parent: Int32,
        ownerOnly: Bool
    ) throws -> Int32 {
        if mkdirat(parent, name, mode_t(0o700)) != 0, errno != EEXIST {
            throw ScriptureModelQualificationError.reportWriteFailed
        }
        let descriptor = openat(parent, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw ScriptureModelQualificationError.reportWriteFailed }
        if ownerOnly, fchmod(descriptor, mode_t(0o700)) != 0 {
            _ = close(descriptor)
            throw ScriptureModelQualificationError.reportWriteFailed
        }
        return descriptor
    }

    private func atomicWrite(
        _ data: Data,
        filename: String,
        directory: Int32
    ) throws {
        let temporary = ".scripture-qualification-\(UUID().uuidString).tmp"
        let descriptor = openat(
            directory,
            temporary,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard descriptor >= 0 else { throw ScriptureModelQualificationError.reportWriteFailed }
        var keepTemporary = true
        defer {
            _ = close(descriptor)
            if keepTemporary { _ = unlinkat(directory, temporary, 0) }
        }
        guard fchmod(descriptor, mode_t(0o600)) == 0 else {
            throw ScriptureModelQualificationError.reportWriteFailed
        }
        try writeAll(data, to: descriptor)
        guard fsync(descriptor) == 0,
            renameatx_np(directory, temporary, directory, filename, UInt32(RENAME_EXCL)) == 0
        else { throw ScriptureModelQualificationError.reportWriteFailed }
        keepTemporary = false
        guard fsync(directory) == 0 else {
            throw ScriptureModelQualificationError.reportWriteFailed
        }
    }

    private func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            guard var pointer = bytes.baseAddress else { return }
            var remaining = bytes.count
            while remaining > 0 {
                let count = Darwin.write(descriptor, pointer, remaining)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else {
                    throw ScriptureModelQualificationError.reportWriteFailed
                }
                remaining -= count
                pointer = pointer.advanced(by: count)
            }
        }
    }

    private func validFilename(_ value: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return value.count <= 128 && value.hasSuffix(".json") && !value.contains("..")
            && value.unicodeScalars.allSatisfy(allowed.contains)
    }
}
