import SwiftUI

struct ReaderViewport: Equatable {
    let offsetY: CGFloat
    let isAtLiveEdge: Bool
}

extension ScrollPhase {
    var isUserDriven: Bool {
        switch self {
        case .tracking, .interacting, .decelerating: true
        case .idle, .animating: false
        }
    }
}
