import SettingsAPI
import SwiftUI

private struct InterfaceDisplayLanguageKey: EnvironmentKey {
    static let defaultValue = DisplayLanguage.simplifiedChinese
}

extension EnvironmentValues {
    var interfaceDisplayLanguage: DisplayLanguage {
        get { self[InterfaceDisplayLanguageKey.self] }
        set { self[InterfaceDisplayLanguageKey.self] = newValue }
    }
}
