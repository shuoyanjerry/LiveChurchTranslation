import LiveReader
import SwiftUI

@main
struct LiveChurchTranslationApp: App {
    private let startup: Startup

    init() {
        do {
            startup = .ready(try AppComposition.build())
        } catch {
            startup = .failed(error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch startup {
            case .ready(let dependencies):
                LiveReaderView(
                    viewModel: dependencies.viewModel,
                    sharingFeature: dependencies.sharingFeature
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
