import AppKit
import ApplicationLifecycle
import AudioImportAPI
import Darwin
import Foundation
import SessionManagementAPI

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    private var shutdownCoordinator: ApplicationShutdownCoordinator?
    private var terminationSignalSource: DispatchSourceSignal?

    func configure(
        controller: any LiveSessionController,
        audioImporter: any AudioImporting,
        modelPreparations: [any ModelPreparationController]
    ) {
        shutdownCoordinator = ApplicationShutdownCoordinator(
            controller: controller,
            audioImporter: audioImporter,
            modelPreparations: modelPreparations
        )
    }

    func applicationDidFinishLaunching(_: Notification) {
        installTerminationSignalHandler()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let shutdownCoordinator else { return .terminateNow }
        shutdownCoordinator.request {
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func installTerminationSignalHandler() {
        guard terminationSignalSource == nil else { return }
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { [weak self] in
            self?.handleTerminationSignal()
        }
        source.activate()
        terminationSignalSource = source
    }

    private func handleTerminationSignal() {
        guard let shutdownCoordinator else {
            Darwin.exit(EXIT_SUCCESS)
        }
        shutdownCoordinator.handleTerminationSignal {
            Darwin.exit(EXIT_SUCCESS)
        }
    }
}
