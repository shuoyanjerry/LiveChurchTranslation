import Foundation
import PersistenceAPI
import SettingsAPI

extension StoredSessionSummary {
    var displayTitle: String {
        title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var recognitionLanguage: String {
        "识别语言：\(sourceLanguage.recognitionLanguageName)"
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

    fileprivate var recognitionLanguageName: String {
        let normalized = lowercased().replacingOccurrences(of: "_", with: "-")
        if normalized == "zh" || normalized == "zh-hans" || normalized.hasPrefix("zh-hans-") {
            return "普通话"
        }
        if normalized == "en" || normalized.hasPrefix("en-") {
            return "英语"
        }
        return localizedLanguageName
    }

    fileprivate var localizedLanguageName: String {
        Locale(identifier: "zh-Hans").localizedString(forLanguageCode: self) ?? self
    }
}
