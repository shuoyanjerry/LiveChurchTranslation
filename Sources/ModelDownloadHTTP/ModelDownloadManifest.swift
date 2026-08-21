import Foundation
import ModelRuntimeAPI

/// One immutable file in a model installation.
public struct ModelArtifactManifest: Equatable, Sendable {
    /// A fixed HTTPS artifact URL, normally containing an immutable revision.
    public let remoteURL: URL
    /// The safe path below this model's private installation directory.
    public let relativePath: String
    /// The exact uncompressed file length.
    public let expectedBytes: Int64
    /// The exact SHA-256 digest in hexadecimal form.
    public let sha256: String

    public init(
        remoteURL: URL,
        relativePath: String,
        expectedBytes: Int64,
        sha256: String
    ) throws {
        try ManifestValidator.validate(remoteURL: remoteURL)
        try ManifestValidator.validate(relativePath: relativePath)
        try ManifestValidator.validate(byteCount: expectedBytes)
        try ManifestValidator.validate(sha256: sha256)
        self.remoteURL = remoteURL
        self.relativePath = relativePath
        self.expectedBytes = expectedBytes
        self.sha256 = sha256.lowercased()
    }
}

/// Selects the URL returned after all artifacts pass validation.
public enum ModelInstallResult: Equatable, Sendable {
    case directory
    case file(relativePath: String)
}

/// A complete, vendor-neutral installation recipe supplied by the composition root.
public struct ModelDownloadManifest: Equatable, Sendable {
    public let descriptor: ModelDescriptor
    public let installDirectoryName: String
    public let artifacts: [ModelArtifactManifest]
    public let result: ModelInstallResult

    public init(
        descriptor: ModelDescriptor,
        installDirectoryName: String,
        artifacts: [ModelArtifactManifest],
        result: ModelInstallResult
    ) throws {
        try ManifestValidator.validate(component: installDirectoryName)
        guard !artifacts.isEmpty else {
            throw ModelManifestError.emptyArtifacts
        }
        let total = try ManifestValidator.totalBytes(in: artifacts)
        guard descriptor.expectedBytes == total else {
            throw ModelManifestError.descriptorSizeMismatch
        }
        try ManifestValidator.validateUniquePaths(in: artifacts)
        try ManifestValidator.validate(result: result, artifacts: artifacts)
        try ManifestValidator.validateDescriptorChecksum(descriptor, artifacts: artifacts)
        self.descriptor = descriptor
        self.installDirectoryName = installDirectoryName
        self.artifacts = artifacts
        self.result = result
    }
}

/// Configuration failures detected before network or filesystem work begins.
public enum ModelManifestError: LocalizedError, Equatable, Sendable {
    case insecureURL(String)
    case invalidRelativePath(String)
    case invalidByteCount
    case invalidSHA256
    case emptyArtifacts
    case descriptorSizeMismatch
    case descriptorChecksumMismatch
    case missingResultArtifact
    case conflictingArtifactPath

    public var errorDescription: String? {
        switch self {
        case .insecureURL: "Every model artifact must use an HTTPS URL."
        case .invalidRelativePath: "A model artifact contains an unsafe relative path."
        case .invalidByteCount: "Artifact byte counts must be positive."
        case .invalidSHA256: "Artifact SHA-256 values must contain 64 hexadecimal characters."
        case .emptyArtifacts: "A model manifest must contain at least one artifact."
        case .descriptorSizeMismatch: "The descriptor size does not match its artifacts."
        case .descriptorChecksumMismatch: "The descriptor checksum does not match its artifact."
        case .missingResultArtifact: "The selected result file is not in the manifest."
        case .conflictingArtifactPath: "Artifact paths must be unique and non-overlapping."
        }
    }
}

enum ManifestValidator {
    static func validate(remoteURL: URL) throws {
        guard remoteURL.scheme?.lowercased() == "https",
            remoteURL.host?.isEmpty == false,
            remoteURL.user == nil,
            remoteURL.password == nil,
            remoteURL.fragment == nil
        else {
            throw ModelManifestError.insecureURL(remoteURL.absoluteString)
        }
    }

    static func validate(relativePath: String) throws {
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !relativePath.hasPrefix("/"), !relativePath.contains("\\"),
            !relativePath.contains("\0"), !components.isEmpty,
            components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            throw ModelManifestError.invalidRelativePath(relativePath)
        }
    }

    static func validate(component: String) throws {
        try validate(relativePath: component)
        guard !component.contains("/") else {
            throw ModelManifestError.invalidRelativePath(component)
        }
    }

    static func validate(byteCount: Int64) throws {
        guard byteCount > 0 else { throw ModelManifestError.invalidByteCount }
    }

    static func validate(sha256: String) throws {
        let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard sha256.utf8.count == 64,
            sha256.unicodeScalars.allSatisfy(hex.contains)
        else { throw ModelManifestError.invalidSHA256 }
    }

    static func totalBytes(in artifacts: [ModelArtifactManifest]) throws -> Int64 {
        try artifacts.reduce(0) { total, artifact in
            let (sum, overflow) = total.addingReportingOverflow(artifact.expectedBytes)
            guard !overflow else { throw ModelManifestError.invalidByteCount }
            return sum
        }
    }

    static func validate(
        result: ModelInstallResult,
        artifacts: [ModelArtifactManifest]
    ) throws {
        guard case .file(let path) = result else { return }
        try validate(relativePath: path)
        guard artifacts.contains(where: { $0.relativePath == path }) else {
            throw ModelManifestError.missingResultArtifact
        }
    }

    static func validateUniquePaths(in artifacts: [ModelArtifactManifest]) throws {
        let paths = artifacts.map { $0.relativePath.lowercased() }.sorted()
        for (first, second) in zip(paths, paths.dropFirst()) {
            guard first != second, !second.hasPrefix(first + "/") else {
                throw ModelManifestError.conflictingArtifactPath
            }
        }
    }

    static func validateDescriptorChecksum(
        _ descriptor: ModelDescriptor,
        artifacts: [ModelArtifactManifest]
    ) throws {
        guard let checksum = descriptor.sha256 else { return }
        try validate(sha256: checksum)
        guard artifacts.count == 1, artifacts[0].sha256 == checksum.lowercased() else {
            throw ModelManifestError.descriptorChecksumMismatch
        }
    }
}
