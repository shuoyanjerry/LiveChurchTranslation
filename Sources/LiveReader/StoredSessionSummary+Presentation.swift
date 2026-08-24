import Foundation
import PersistenceAPI
import SettingsAPI

extension StoredSessionSummary {
    var displayTitle: String {
        title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var languagePair: String {
        if let mode = storedTranslationMode {
            return mode.displayName
        }
        return "\(sourceLanguage.localizedLanguageName) → \(targetLanguage.localizedLanguageName)"
    }

    var storedTranslationMode: TranslationMode? {
        TranslationMode(
            sourceLanguageTag: sourceLanguage,
            targetLanguageTag: targetLanguage
        )
    }

    var hasIncompleteSpeechSegments: Bool {
        pendingRecordCount > 0 || rejectedSentenceCount > 0
    }

    var retranscriptionTitle: String {
        let suffix = "（重新听抄）"
        return displayTitle.hasSuffix(suffix) ? displayTitle : displayTitle + suffix
    }
}

extension String {
    fileprivate var nonEmpty: String? { isEmpty ? nil : self }

    fileprivate var localizedLanguageName: String {
        Locale(identifier: "zh-Hans").localizedString(forLanguageCode: self) ?? self
    }
}
