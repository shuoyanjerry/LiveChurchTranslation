import Foundation
import PersistenceAPI
import TranscriptAPI

enum TranscriptMarkdown {
    static func header(
        for session: TranscriptSession,
        integrity: StoredTranscriptIntegrity
    ) -> String {
        var metadata = [
            "- 类型：\(session.kind.markdownName)",
            "- 识别语言：\(languageName(session.sourceLanguage))",
            "- 开始时间：\(dateTime(session.startedAt))",
            "- 结束时间：\(session.endedAt.map(dateTime) ?? "进行中")",
            "- 记录状态：\(integrity.markdownLabel)",
        ]
        if let title = safeInlineText(session.title) {
            metadata.insert("- 标题：\(title)", at: 1)
        }
        return "# \(session.kind.markdownDocumentTitle)\n\n"
            + metadata.joined(separator: "\n")
            + "\n\n---\n\n"
    }

    static func entry(_ entry: TranscriptEntry) -> String {
        let interval = "\(timestamp(entry.startedMilliseconds))–\(timestamp(entry.endedMilliseconds))"
        return "## 片段 \(entry.sequence) · \(interval)\n\n"
            + "**识别文字**\n\n\(safeText(entry.sourceText))\n\n"
    }

    private static func dateTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .numeric, time: .standard)
                .locale(Locale(identifier: "zh_Hans_CN"))
        )
    }

    private static func timestamp(_ milliseconds: Int64) -> String {
        let value = max(0, milliseconds)
        let hours = value / 3_600_000
        let minutes = (value % 3_600_000) / 60_000
        let seconds = (value % 60_000) / 1_000
        let remainder = value % 1_000
        return String(
            format: "%02lld:%02lld:%02lld.%03lld",
            hours,
            minutes,
            seconds,
            remainder
        )
    }

    private static func languageName(_ identifier: String) -> String {
        let normalized = identifier.lowercased().replacingOccurrences(of: "_", with: "-")
        if normalized == "zh-hans" || normalized.hasPrefix("zh-hans-") {
            return "简体中文"
        }
        if normalized == "zh" || normalized.hasPrefix("zh-") {
            return "中文"
        }
        if normalized == "en" || normalized.hasPrefix("en-") {
            return "英文"
        }
        return safeInlineText(identifier) ?? "未标明"
    }

    private static func safeInlineText(_ value: String?) -> String? {
        guard let value else { return nil }
        let singleLine = value.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
        guard !singleLine.isEmpty else { return nil }
        return safeText(singleLine)
    }

    private static func safeText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(escapeLine)
            .joined(separator: "\n")
    }

    private static func escapeLine(_ line: Substring) -> String {
        var result = ""
        var isLeadingWhitespace = true
        for scalar in line.unicodeScalars {
            if isLeadingWhitespace, scalar.value == 0x20 || scalar.value == 0x09 {
                result += scalar.value == 0x20 ? "&#32;" : "&#9;"
                continue
            }
            isLeadingWhitespace = false
            appendEscaped(scalar, to: &result)
        }
        return result
    }

    private static func appendEscaped(_ scalar: Unicode.Scalar, to result: inout String) {
        switch scalar.value {
        case 0x26:
            result += "&amp;"
        case 0x3C:
            result += "&lt;"
        case 0x00...0x08, 0x0B...0x1F, 0x7F:
            result.append("\u{FFFD}")
        case 0x21, 0x23...0x24, 0x28...0x2B, 0x2D...0x2E, 0x3D...0x3E,
            0x5B...0x60, 0x7B...0x7E:
            result.append("\\")
            result.unicodeScalars.append(scalar)
        default:
            result.unicodeScalars.append(scalar)
        }
    }
}

extension TranscriptSessionKind {
    fileprivate var markdownDocumentTitle: String {
        switch self {
        case .live: "会议听抄稿"
        case .importedAudio: "导入音频听抄稿"
        }
    }

    fileprivate var markdownName: String {
        switch self {
        case .live: "现场会议"
        case .importedAudio: "导入音频"
        }
    }
}

extension StoredTranscriptIntegrity {
    fileprivate var markdownLabel: String {
        switch self {
        case .active: "处理中"
        case .complete: "完整"
        case .incomplete: "可能不完整"
        case .recoveredAfterInterruption: "中断后恢复，可能不完整"
        }
    }
}
