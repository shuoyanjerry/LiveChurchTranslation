import Foundation
import PersistenceAPI
import SettingsAPI

extension StoredSessionSummary {
    var displayTitle: String {
        title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var languagePair: String {
        if let mode = TranslationMode(
            sourceLanguageTag: sourceLanguage,
            targetLanguageTag: targetLanguage
        ) {
            return mode.displayName
        }
        return "\(sourceLanguage.localizedLanguageName) → \(targetLanguage.localizedLanguageName)"
    }

}

extension String {
    fileprivate var nonEmpty: String? { isEmpty ? nil : self }

    fileprivate var localizedLanguageName: String {
        Locale(identifier: "zh-Hans").localizedString(forLanguageCode: self) ?? self
    }
}
