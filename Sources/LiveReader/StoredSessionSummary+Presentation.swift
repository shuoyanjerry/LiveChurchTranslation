import Foundation
import PersistenceAPI
import SettingsAPI

extension StoredSessionSummary {
    var displayTitle: String {
        title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var recognitionLanguage: String {
        recognitionLanguage(displayLanguage: .simplifiedChinese)
    }

    func recognitionLanguage(displayLanguage: DisplayLanguage) -> String {
        let prefix = displayLanguage.interfaceText("识别语言：")
        return prefix + sourceLanguage.recognitionLanguageName(displayLanguage: displayLanguage)
    }

    var storedRecognitionMode: TranslationMode? {
        sourceLanguage.recognitionMode
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

    fileprivate var recognitionMode: TranslationMode? {
        let tag = lowercased().replacingOccurrences(of: "_", with: "-")
        let isMandarin =
            tag == "zh" || tag == "zh-hans" || tag.hasPrefix("zh-hans-")
            || tag == "zh-cn" || tag.hasPrefix("zh-cn-")
        if isMandarin {
            return .mandarinToEnglish
        }
        if tag == "en" || tag.hasPrefix("en-") {
            return .englishToSimplifiedChinese
        }
        return nil
    }

    fileprivate func recognitionLanguageName(displayLanguage: DisplayLanguage) -> String {
        switch recognitionMode {
        case .mandarinToEnglish:
            return displayLanguage.interfaceText("普通话")
        case .englishToSimplifiedChinese:
            return displayLanguage.interfaceText("英语")
        case nil:
            let simplifiedName =
                Locale(identifier: "zh-Hans")
                .localizedString(forLanguageCode: self) ?? self
            return displayLanguage.interfaceText(simplifiedName)
        }
    }
}
