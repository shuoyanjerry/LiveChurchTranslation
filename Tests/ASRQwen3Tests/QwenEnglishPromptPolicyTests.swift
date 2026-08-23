import Testing

@Suite("Qwen English production context prompt")
struct QwenEnglishPromptPolicyTests {
    @Test("uses the production selector and retains ambiguous worship vocabulary")
    func containsRequiredMorphologyWithoutReferencePhrases() {
        let prompt = QwenEnglishQualificationRunner.prompt
        let terms = prompt.split(separator: ",").map(String.init)

        #expect(terms.count == 18)
        #expect(Set(terms).count == terms.count)
        #expect(terms.last == "gracious")
        for expected in [
            "prayer", "pray", "prays", "praying", "praise", "praises", "praising",
            "grace", "gracious",
        ] {
            #expect(terms.contains(expected))
        }
        #expect(!prompt.localizedCaseInsensitiveContains("prayer asks"))
        #expect(!terms.contains("asks"))
    }
}
