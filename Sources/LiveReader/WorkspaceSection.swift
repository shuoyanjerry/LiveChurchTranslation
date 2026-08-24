enum WorkspaceSection: String, CaseIterable, Identifiable {
    case live
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live: "实时"
        case .library: "资料库"
        }
    }

    var icon: String {
        switch self {
        case .live: "waveform.and.mic"
        case .library: "books.vertical"
        }
    }
}
