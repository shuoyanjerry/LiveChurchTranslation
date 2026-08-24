import Foundation
@testable import TranslationHyMT2

actor FakeLlamaServerController: LlamaServerControlling {
    private let remainsRunningAfterLaunch: Bool
    private var running = false
    private var launches: [LlamaServerLaunchRequest] = []
    private var stopCount = 0

    init(remainsRunningAfterLaunch: Bool = true) {
        self.remainsRunningAfterLaunch = remainsRunningAfterLaunch
    }

    func launch(_ request: LlamaServerLaunchRequest) {
        launches.append(request)
        running = remainsRunningAfterLaunch
    }

    func isRunning() -> Bool {
        running
    }

    func stop() {
        running = false
        stopCount += 1
    }

    func launchRequests() -> [LlamaServerLaunchRequest] {
        launches
    }

    func stops() -> Int {
        stopCount
    }
}

actor FakeLlamaServerTransport: LlamaServerTransport {
    private var healthFailuresRemaining: Int
    private var responses: [Result<String, HyMT2Error>]
    private var healthChecks = 0
    private var requests: [LlamaCompletionRequest] = []
    private let cancellationRequestIndices: Set<Int>

    init(
        healthFailures: Int = 0,
        responses: [Result<String, HyMT2Error>] = [],
        cancellationRequestIndices: Set<Int> = []
    ) {
        healthFailuresRemaining = healthFailures
        self.responses = responses
        self.cancellationRequestIndices = cancellationRequestIndices
    }

    func checkHealth(
        at _: LlamaServerEndpoint,
        timeout _: TimeInterval
    ) throws {
        healthChecks += 1
        if healthFailuresRemaining > 0 {
            healthFailuresRemaining -= 1
            throw HyMT2Error.transportFailure("not ready")
        }
    }

    func complete(
        _ request: LlamaCompletionRequest,
        at _: LlamaServerEndpoint,
        timeout _: TimeInterval
    ) throws -> String {
        let requestIndex = requests.count
        requests.append(request)
        if cancellationRequestIndices.contains(requestIndex) {
            throw CancellationError()
        }
        guard !responses.isEmpty else {
            throw HyMT2Error.transportFailure("missing fake response")
        }
        return try responses.removeFirst().get()
    }

    func checkedHealthCount() -> Int {
        healthChecks
    }

    func completionRequests() -> [LlamaCompletionRequest] {
        requests
    }
}

actor FakeHyMT2ReadinessTiming: HyMT2ReadinessTiming {
    private var elapsed: Duration = .zero

    func now() -> Duration {
        elapsed
    }

    func sleep(for duration: Duration) {
        elapsed += max(duration, .zero)
    }
}

final class TemporaryGGUF {
    let directoryURL: URL
    let fileURL: URL

    init(filename: String = "Hy-MT2-1.8B-Q4_K_M.gguf") throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        fileURL = directoryURL.appendingPathComponent(filename)
        try Data([0x47, 0x47, 0x55, 0x46]).write(to: fileURL)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    deinit {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

enum HyMT2TestSupport {
    static let endpoint = LlamaServerEndpoint(
        port: 55_321,
        apiKey: "test-api-key"
    )

    static func configuration(
        startupTimeout: Duration = .seconds(1),
        healthPollInterval: Duration = .milliseconds(1)
    ) -> HyMT2Configuration {
        HyMT2Configuration(
            startupTimeout: startupTimeout,
            healthPollInterval: healthPollInterval,
            requestTimeout: 1,
            maximumOutputTokens: 128,
            threadCount: 2
        )
    }
}
