enum MicrophoneControlPresentation {
    static let settingsTitle = "麦克风设置"

    static func title(selectedInputName: String, expanded: Bool) -> String {
        expanded ? selectedInputName : settingsTitle
    }
}
