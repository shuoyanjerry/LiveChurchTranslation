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

    var integrityLabel: String? {
        switch integrity {
        case .complete:
            nil
        case .active:
            "处理中"
        case .incomplete:
            "内容不完整"
        case .recoveredAfterInterruption:
            "中断后恢复 · 请核对"
        }
    }

    var integrityDetail: String? {
        switch integrity {
        case .complete:
            nil
        case .active:
            "这场会议尚未完成保存。"
        case .incomplete:
            "部分内容未能完成处理，请结合完整录音核对。"
        case .recoveredAfterInterruption:
            "听抄稿在应用意外中断后自动恢复，建议结合录音核对。"
        }
    }
}

extension String {
    fileprivate var nonEmpty: String? { isEmpty ? nil : self }

    fileprivate var localizedLanguageName: String {
        Locale(identifier: "zh-Hans").localizedString(forLanguageCode: self) ?? self
    }
}
