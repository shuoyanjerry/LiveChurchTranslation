import ASRQwen3
import Testing

@Suite("Qwen3 ASR configuration")
struct Qwen3ASRConfigurationTests {
    @Test("defaults to the qualified Apple Silicon thread count")
    func qualifiedDefaultThreadCount() {
        #expect(Qwen3ASRConfiguration().inferenceThreads == 4)
    }

    @Test("keeps explicit thread injection replaceable")
    func explicitThreadCount() {
        #expect(Qwen3ASRConfiguration(inferenceThreads: 2).inferenceThreads == 2)
    }
}
