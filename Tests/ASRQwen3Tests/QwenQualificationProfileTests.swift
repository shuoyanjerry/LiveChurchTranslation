import Testing

@Suite("Qwen qualification thread profiles")
struct QwenQualificationProfileTests {
    @Test("uses the existing two-thread baseline only when the profile is absent")
    func defaultsToBaseline() throws {
        let profile = try QwenQualificationProfile(environmentValue: nil)

        #expect(profile == .baseline2)
        #expect(profile.inferenceThreads == 2)
    }

    @Test("accepts only the bounded experimental profiles")
    func acceptsBoundedProfiles() throws {
        #expect(try QwenQualificationProfile(environmentValue: "threads4") == .threads4)
        #expect(try QwenQualificationProfile(environmentValue: "threads6") == .threads6)
    }

    @Test(
        "rejects every unapproved profile spelling",
        arguments: ["", "baseline2", "threads2", "threads8", "4", " threads4"]
    )
    func rejectsUnapprovedProfile(_ value: String) {
        #expect(throws: QwenQualificationProfileError.unsupportedValue(value)) {
            try QwenQualificationProfile(environmentValue: value)
        }
    }

    @Test("writes the selected profile into runtime configuration and report metadata")
    func profileControlsConfigurationAndMetadata() {
        for profile in [
            QwenQualificationProfile.baseline2,
            .threads4,
            .threads6,
        ] {
            let configuration = QwenQualificationConfiguration.providerConfiguration(
                for: profile
            )
            let metadata = QwenQualificationConfiguration.providerMetadata(for: profile)

            #expect(configuration.inferenceThreads == profile.inferenceThreads)
            #expect(metadata.settings["inferenceThreads"] == String(profile.inferenceThreads))
            #expect(metadata.settings["qualificationProfile"] == profile.rawValue)
            #expect(metadata.settings["artifactVerification"] == "sixFilesBytesAndSHA256")
            #expect(metadata.settings["contextPrompt"] == QwenQualificationConfiguration.prompt)
        }
    }
}
