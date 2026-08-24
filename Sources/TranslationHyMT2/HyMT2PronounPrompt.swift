import TranslationAPI

enum HyMT2PronounPrompt {
    static let generalRule =
        "口语 tā 即使写成他或她也可能没有性别证据；无明确证据时使用自然的单数 they，"
        + "不要使用 he 或 she，也不要根据姓名、职业或刻板印象猜测。"

    static func section(_ occurrences: [HyMT2PronounOccurrence]) -> String {
        let presentCodes = Set(
            occurrences.map { HyMT2PronounResolutionToken.compactCode(for: $0.resolution) }
        )
        let definitions = definitionOrder.compactMap { code in
            presentCodes.contains(code) ? definition(for: code) : nil
        }
        return
            ([
                HyMT2PromptControlDelimiter.pronounAlignmentOpening,
                "源文中每个 <Q...N/F/M/D> 标记都紧跟在一个代词或“代词的”所有格结构后。",
                "末尾字母是该处经过核验的决策；标记本身不是要翻译的正文。",
            ] + definitions + [
                "翻译每个代词或所有格结构，把标记原样放在该英文代词后；每个标记只出现一次。",
                "标记与对应代词必须一起移动；可采用自然英文语序，但不得把标记交给别的代词。",
                "每处只能输出一个符合句法的代词，禁止列出备选词或使用斜线。",
            ]).joined(separator: "\n")
    }

    private static let definitionOrder: [Character] = ["N", "F", "M", "D"]

    private static func definition(for code: Character) -> String? {
        switch code {
        case "N":
            "N=性别未知的单数人物；忽略标记前的他或她字形，禁止使用 he 或 she，"
                + "只选一个符合句法的单数 they 形式。"
        case "F":
            "F=已确认女性，只选一个符合句法的 she 形式。"
        case "M":
            "M=已确认男性，只选一个符合句法的 he 形式。"
        case "D":
            "D=基督教神性指代，只选一个符合句法的 he 形式。"
        default:
            nil
        }
    }
}
