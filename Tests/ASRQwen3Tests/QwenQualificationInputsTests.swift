import Testing

@Suite("Qwen qualification inputs")
struct QwenQualificationInputsTests {
    @Test("requires every frozen qualification input", arguments: requiredKeys)
    func rejectsMissingInput(_ missingKey: String) {
        var environment = Self.environment
        environment.removeValue(forKey: missingKey)

        #expect(throws: QwenQualificationInputError.missingEnvironment(missingKey)) {
            try QwenQualificationInputs(environment: environment)
        }
    }

    @Test("rejects partial-corpus, prompt, and arbitrary thread overrides")
    func rejectsUnsupportedOverrides() {
        for key in [
            "QWEN_INFERENCE_THREADS",
            "MANDARIN_ASR_MAX_CLIPS",
            "MANDARIN_ASR_PROMPT",
        ] {
            var environment = Self.environment
            environment[key] = "override"
            #expect(throws: QwenQualificationInputError.unsupportedOverride(key)) {
                try QwenQualificationInputs(environment: environment)
            }
        }
    }

    @Test("accepts the bounded four-thread profile")
    func acceptsBoundedProfile() throws {
        var environment = Self.environment
        environment["QWEN_QUALIFICATION_PROFILE"] = "threads4"

        let inputs = try QwenQualificationInputs(environment: environment)

        #expect(inputs.profile == .threads4)
    }

    private static let requiredKeys = [
        "QWEN_MODEL_DIR",
        "MANDARIN_ASR_QUALIFICATION_MANIFEST",
        "MANDARIN_ASR_REFERENCE_MANIFEST",
        "MANDARIN_ASR_WAV_DIR",
        "QWEN_ASR_REPORT",
    ]

    private static let environment = [
        "QWEN_MODEL_DIR": "/model",
        "MANDARIN_ASR_QUALIFICATION_MANIFEST": "/qualification.json",
        "MANDARIN_ASR_REFERENCE_MANIFEST": "/references.json",
        "MANDARIN_ASR_WAV_DIR": "/wav",
        "QWEN_ASR_REPORT": "/qwen-report.json",
    ]
}
