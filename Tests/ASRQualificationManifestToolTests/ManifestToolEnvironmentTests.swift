import Testing

@Suite struct ManifestToolEnvironmentTests {
    @Test func noEnvironmentDisablesTool() throws {
        #expect(try ManifestToolEnvironment.inputs(from: [:]) == nil)
    }

    @Test func partialEnvironmentFailsClosed() {
        do {
            _ = try ManifestToolEnvironment.inputs(from: [
                "ASR_QUALIFICATION_VAD_REPORT": "/vad.json"
            ])
            Issue.record("Expected incomplete environment")
        } catch let error as ManifestToolError {
            guard case .incompleteEnvironment(let missing) = error else {
                Issue.record("Unexpected tool error: \(error)")
                return
            }
            #expect(missing.count == 4)
            #expect(missing.contains("ASR_QUALIFICATION_OUTPUT"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
