import LiveReader
import OSLog
import SwiftUI

public struct LiveChurchTranslationApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var lifecycle
    private let startup: Startup

    public init() {
        do {
            let dependencies = try AppComposition.build()
            startup = .ready(dependencies)
            lifecycle.configure(
                controller: dependencies.controller,
                audioImporter: dependencies.audioImporter,
                modelPreparations: dependencies.modelPreparations
            )
        } catch {
            Logger(
                subsystem: "com.shuoyan.LiveChurchTranslation",
                category: "startup"
            ).fault("Startup failed: \(error.localizedDescription, privacy: .private)")
            startup = .failed
        }
    }

    public var body: some Scene {
        WindowGroup {
            switch startup {
            case .ready(let dependencies):
                AppWorkspaceView(
                    liveViewModel: dependencies.viewModel,
                    libraryViewModel: dependencies.libraryViewModel,
                    permissionCoordinator: dependencies.permissionCoordinator,
                    sharingFeature: dependencies.sharingFeature,
                    audioImporter: dependencies.audioImporter
                )
            case .failed:
                StartupFailureView()
            }
        }
        .windowResizability(.contentMinSize)
    }
}

private enum Startup {
    case ready(AppSceneDependencies)
    case failed
}
