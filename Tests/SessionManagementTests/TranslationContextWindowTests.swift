@testable import SessionManagement
import Testing
import TranslationAPI

@Suite struct TranslationContextWindowTests {
    @Test func retainsOnlyTheLatestTwoFinalizedInMemoryTranslations() {
        var window = TranslationContextWindow()

        window.append(entry("一", "One"))
        window.append(entry("二", "Two"))
        window.append(entry("三", "Three"))

        #expect(window.entries == [entry("二", "Two"), entry("三", "Three")])
    }

    @Test func resetPreventsContextFromCrossingSessionBoundaries() {
        var window = TranslationContextWindow()
        window.append(entry("上一场", "Previous session"))

        window.removeAll()

        #expect(window.entries.isEmpty)
    }

    private func entry(_ source: String, _ target: String) -> TranslationContextEntry {
        TranslationContextEntry(sourceText: source, targetText: target)
    }
}
