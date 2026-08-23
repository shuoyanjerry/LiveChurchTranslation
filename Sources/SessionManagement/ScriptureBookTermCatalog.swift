import Foundation
import SettingsAPI
import TranslationAPI

enum ScriptureBookTermCatalog {
    static var count: Int { books.count }

    static func matchedTerms(
        in source: String,
        mode: TranslationMode
    ) -> [TranslationTerm] {
        books.compactMap { book in
            let term = book.term(mode: mode)
            let candidates = [term.source] + term.sourceAliases
            return candidates.contains { matches($0, in: source, mode: mode) } ? term : nil
        }
    }

    private static func matches(
        _ candidate: String,
        in source: String,
        mode: TranslationMode
    ) -> Bool {
        guard mode == .englishToSimplifiedChinese else {
            return source.localizedStandardContains(candidate)
        }
        let escaped = NSRegularExpression.escapedPattern(for: candidate)
        return source.range(
            of: "(?i)(?<![A-Za-z])\(escaped)(?![A-Za-z])",
            options: .regularExpression
        ) != nil
    }

    private struct Book: Sendable {
        let english: String
        let chinese: String
        let englishAliases: [String]

        init(_ english: String, _ chinese: String, _ aliases: [String] = []) {
            self.english = english
            self.chinese = chinese
            englishAliases = aliases
        }

        func term(mode: TranslationMode) -> TranslationTerm {
            switch mode {
            case .mandarinToEnglish:
                TranslationTerm(source: chinese, target: english)
            case .englishToSimplifiedChinese:
                TranslationTerm(
                    source: english,
                    target: chinese,
                    sourceAliases: englishAliases
                )
            }
        }
    }

    private static let books: [Book] = [
        Book("Genesis", "创世记"), Book("Exodus", "出埃及记"), Book("Leviticus", "利未记"),
        Book("Numbers", "民数记"), Book("Deuteronomy", "申命记"), Book("Joshua", "约书亚记"),
        Book("Judges", "士师记"), Book("Ruth", "路得记"),
        Book("1 Samuel", "撒母耳记上", ["First Samuel", "1st Samuel"]),
        Book("2 Samuel", "撒母耳记下", ["Second Samuel", "2nd Samuel"]),
        Book("1 Kings", "列王纪上", ["First Kings", "1st Kings"]),
        Book("2 Kings", "列王纪下", ["Second Kings", "2nd Kings"]),
        Book("1 Chronicles", "历代志上", ["First Chronicles", "1st Chronicles"]),
        Book("2 Chronicles", "历代志下", ["Second Chronicles", "2nd Chronicles"]),
        Book("Ezra", "以斯拉记"), Book("Nehemiah", "尼希米记"),
        Book("Esther", "以斯帖记"), Book("Job", "约伯记"), Book("Psalms", "诗篇", ["Psalm"]),
        Book("Proverbs", "箴言"), Book("Ecclesiastes", "传道书"),
        Book("Song of Solomon", "雅歌", ["Song of Songs"]), Book("Isaiah", "以赛亚书"),
        Book("Jeremiah", "耶利米书"), Book("Lamentations", "耶利米哀歌"),
        Book("Ezekiel", "以西结书"), Book("Daniel", "但以理书"), Book("Hosea", "何西阿书"),
        Book("Joel", "约珥书"), Book("Amos", "阿摩司书"), Book("Obadiah", "俄巴底亚书"),
        Book("Jonah", "约拿书"), Book("Micah", "弥迦书"), Book("Nahum", "那鸿书"),
        Book("Habakkuk", "哈巴谷书"), Book("Zephaniah", "西番雅书"),
        Book("Haggai", "哈该书"), Book("Zechariah", "撒迦利亚书"),
        Book("Malachi", "玛拉基书"), Book("Matthew", "马太福音"), Book("Mark", "马可福音"),
        Book("Luke", "路加福音"), Book("John", "约翰福音"), Book("Acts", "使徒行传"),
        Book("Romans", "罗马书"),
        Book("1 Corinthians", "哥林多前书", ["First Corinthians", "1st Corinthians"]),
        Book("2 Corinthians", "哥林多后书", ["Second Corinthians", "2nd Corinthians"]),
        Book("Galatians", "加拉太书"), Book("Ephesians", "以弗所书"),
        Book("Philippians", "腓立比书"), Book("Colossians", "歌罗西书"),
        Book("1 Thessalonians", "帖撒罗尼迦前书", ["First Thessalonians", "1st Thessalonians"]),
        Book("2 Thessalonians", "帖撒罗尼迦后书", ["Second Thessalonians", "2nd Thessalonians"]),
        Book("1 Timothy", "提摩太前书", ["First Timothy", "1st Timothy"]),
        Book("2 Timothy", "提摩太后书", ["Second Timothy", "2nd Timothy"]),
        Book("Titus", "提多书"), Book("Philemon", "腓利门书"), Book("Hebrews", "希伯来书"),
        Book("James", "雅各书"),
        Book("1 Peter", "彼得前书", ["First Peter", "1st Peter"]),
        Book("2 Peter", "彼得后书", ["Second Peter", "2nd Peter"]),
        Book("1 John", "约翰一书", ["First John", "1st John"]),
        Book("2 John", "约翰二书", ["Second John", "2nd John"]),
        Book("3 John", "约翰三书", ["Third John", "3rd John"]),
        Book("Jude", "犹大书"), Book("Revelation", "启示录"),
    ]
}
