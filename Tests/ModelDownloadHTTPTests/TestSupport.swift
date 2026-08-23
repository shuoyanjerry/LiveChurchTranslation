import CryptoKit
import Foundation
import ModelDownloadHTTP
import ModelRuntimeAPI

actor FakeModelHTTPTransport: ModelHTTPTransport {
    private let payloads: [URL: Data]
    private let delay: Duration?
    private let reportedLengthOffset: Int64
    private var requests: [URL] = []
    private var maximumByteCounts: [Int64] = []

    init(
        payloads: [URL: Data],
        delay: Duration? = nil,
        reportedLengthOffset: Int64 = 0
    ) {
        self.payloads = payloads
        self.delay = delay
        self.reportedLengthOffset = reportedLengthOffset
    }

    func download(
        from remoteURL: URL,
        to localURL: URL,
        maximumBytes: Int64,
        progress: @escaping ModelHTTPProgress
    ) async throws -> ModelHTTPTransferResult {
        requests.append(remoteURL)
        maximumByteCounts.append(maximumBytes)
        if let delay { try await Task.sleep(for: delay) }
        try Task.checkCancellation()
        guard let data = payloads[remoteURL] else {
            throw URLError(.fileDoesNotExist)
        }
        guard data.count <= maximumBytes else {
            throw ModelHTTPTransportError.responseTooLarge(maximumBytes: maximumBytes)
        }
        let midpoint = data.count / 2
        progress(Int64(midpoint), Int64(data.count))
        try data.write(to: localURL)
        progress(Int64(data.count), Int64(data.count))
        return ModelHTTPTransferResult(
            statusCode: 200,
            contentLength: Int64(data.count) + reportedLengthOffset
        )
    }

    func requestCount() -> Int { requests.count }
    func requestedMaximumBytes() -> [Int64] { maximumByteCounts }
}

actor TestModelLocationStore: ModelLocationStore {
    private var locations: [ModelID: URL] = [:]

    func location(for modelID: ModelID) -> URL? { locations[modelID] }

    func register(_ location: URL, for modelID: ModelID) {
        locations[modelID] = location
    }

    func removeLocation(for modelID: ModelID) {
        locations[modelID] = nil
    }
}

actor TestRuntimeReporter: ModelRuntimeReporting {
    private var statuses: [ModelID: ModelRuntimeStatus] = [:]
    private var recorded: [ModelRuntimeStatus] = []

    func status(for descriptor: ModelDescriptor) -> ModelRuntimeStatus {
        statuses[descriptor.id]
            ?? ModelRuntimeStatus(
                descriptor: descriptor,
                state: .missing
            )
    }

    func setState(_ state: ModelRuntimeState, for descriptor: ModelDescriptor) {
        let status = ModelRuntimeStatus(descriptor: descriptor, state: state)
        statuses[descriptor.id] = status
        recorded.append(status)
    }

    func events() -> AsyncStream<ModelRuntimeStatus> {
        AsyncStream { continuation in continuation.finish() }
    }

    func history() -> [ModelRuntimeStatus] { recorded }
}

struct TestArtifact {
    let remoteURL: URL
    let relativePath: String
    let data: Data

    func manifest() throws -> ModelArtifactManifest {
        try ModelArtifactManifest(
            remoteURL: remoteURL,
            relativePath: relativePath,
            expectedBytes: Int64(data.count),
            sha256: sha256(data)
        )
    }
}

func makeManifest(
    id: String = "test-model",
    artifacts: [TestArtifact],
    result: ModelInstallResult = .directory
) throws -> ModelDownloadManifest {
    let artifactManifests = try artifacts.map { try $0.manifest() }
    let total = artifactManifests.reduce(0) { $0 + $1.expectedBytes }
    let descriptor = ModelDescriptor(
        id: ModelID(rawValue: id),
        displayName: "Test Model",
        version: "immutable-revision",
        expectedBytes: total,
        sha256: artifactManifests.count == 1 ? artifactManifests[0].sha256 : nil,
        license: "Apache-2.0"
    )
    return try ModelDownloadManifest(
        descriptor: descriptor,
        installDirectoryName: id,
        artifacts: artifactManifests,
        result: result
    )
}

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

@MainActor
final class TestDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}
