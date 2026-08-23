import LiveReader
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
                audioImporter: dependencies.audioImporter
            )
        } catch {
            startup = .failed(error.localizedDescription)
        }
    }

    public var body: some Scene {
        WindowGroup {
            switch startup {
            case .ready(let dependencies):
                AppWorkspaceView(
                    liveViewModel: dependencies.viewModel,
                    libraryViewModel: dependencies.libraryViewModel,
                    sharingFeature: dependencies.sharingFeature,
                    audioImporter: dependencies.audioImporter
                )
            case .failed(let message):
                StartupFailureView(message: message)
            }
        }
        .windowResizability(.contentMinSize)
    }
}

private enum Startup {
    case ready(AppSceneDependencies)
    case failed(String)
}
