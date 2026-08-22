import Darwin
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
        if let active, active.isRunning {
            stop(active)
        }
    }

    private func stop(_ active: Process) {
        active.terminate()
        if waitForExit(active, timeout: 2.0) { return }
        active.interrupt()
        if waitForExit(active, timeout: 1.0) { return }
        _ = Darwin.kill(active.processIdentifier, SIGKILL)
        active.waitUntilExit()
    }

    private func waitForExit(_ process: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        return !process.isRunning
    }

    deinit {
        stop()
    }
}
