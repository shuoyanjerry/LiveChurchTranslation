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
            case .ready(let viewModel):
                LiveReaderView(viewModel: viewModel)
            case .failed(let message):
                StartupFailureView(message: message)
            }
        }
        .windowResizability(.contentMinSize)
    }
}

private enum Startup {
    case ready(LiveReaderViewModel)
    case failed(String)
}
