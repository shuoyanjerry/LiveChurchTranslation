import AppKit
import LiveReader
import SessionManagementAPI

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    private var controller: (any LiveSessionController)?
    private var audioImporter: (any AudioImporting)?
    private var terminationIsPending = false

    func configure(
        controller: any LiveSessionController,
        audioImporter: any AudioImporting
    ) {
        self.controller = controller
        self.audioImporter = audioImporter
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller else { return .terminateNow }
        guard !terminationIsPending else { return .terminateLater }
        terminationIsPending = true
        let audioImporter = audioImporter
        Task {
            await audioImporter?.cancelImport()
            await controller.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
