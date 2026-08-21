import Foundation

actor FoundationLlamaServerController: LlamaServerControlling {
    private let executableURL: URL
    private let managedProcess: ManagedHelperProcess
    private let terminationObserver: HelperTerminationObserver

    init(executableURL: URL) {
        self.executableURL = executableURL
        let managedProcess = ManagedHelperProcess()
        self.managedProcess = managedProcess
        terminationObserver = HelperTerminationObserver(managedProcess: managedProcess)
    }

    func launch(_ request: LlamaServerLaunchRequest) throws {
        stop()
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw HyMT2Error.helperUnavailable(executableURL.path)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments(for: request)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            managedProcess.install(process)
        } catch {
            throw HyMT2Error.launchFailed(error.localizedDescription)
        }
    }

    func isRunning() -> Bool {
        managedProcess.isRunning
    }

    func stop() {
        managedProcess.stop()
    }

    private func arguments(for request: LlamaServerLaunchRequest) -> [String] {
        [
            "--model", request.modelURL.path,
            "--host", request.endpoint.host,
            "--port", String(request.endpoint.port),
            "--api-key", request.endpoint.apiKey,
            "--ctx-size", String(request.contextSize),
            "--threads", String(request.threadCount),
            "--parallel", "1",
            "--n-gpu-layers", String(request.gpuLayerCount),
            "--jinja",
        ]
    }
}
