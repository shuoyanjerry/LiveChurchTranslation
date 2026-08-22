import Foundation
@testable import TranslationHyMT2
import Testing

@Suite("Managed helper process")
struct ManagedHelperProcessTests {
    @Test func stopTerminatesARealChildProcess() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["60"]
        try child.run()
        let managed = ManagedHelperProcess()
        managed.install(child)
        #expect(managed.isRunning)

        managed.stop()

        #expect(!managed.isRunning)
        #expect(!child.isRunning)
    }
}
