import Foundation

final class ManagedHelperProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?

    var isRunning: Bool {
        lock.withLock { process?.isRunning == true }
    }

    func install(_ process: Process) {
        lock.withLock { self.process = process }
    }

    func stop() {
        let active = lock.withLock { () -> Process? in
            defer { process = nil }
            return process
        }
        if active?.isRunning == true {
            active?.terminate()
        }
    }

    deinit {
        stop()
    }
}
