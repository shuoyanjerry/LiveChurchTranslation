import Testing
import TranslationQualificationSupport

@Suite struct DiscourseQualificationConfigurationTests {
    @Test func absentEnvironmentDoesNotRequestQualification() throws {
        #expect(!DiscourseQualificationConfiguration.isRequested([:]))
        #expect(try DiscourseQualificationConfiguration.load([:]) == nil)
    }

    @Test func sharedManifestAloneDoesNotActivateThePrivateLane() throws {
        let environment = [
            DiscourseQualificationConfiguration.manifestKey: "/private/manifest.json"
        ]
        #expect(!DiscourseQualificationConfiguration.isRequested(environment))
        #expect(try DiscourseQualificationConfiguration.load(environment) == nil)
    }

    @Test func explicitReportWithoutManifestFailsClosed() {
        let environment = [
            DiscourseQualificationConfiguration.reportKey: "report.json"
        ]
        #expect(throws: TranslationQualificationError.self) {
            _ = try DiscourseQualificationConfiguration.load(environment)
        }
    }

    @Test func unsafeReportFilenameFailsClosed() {
        var environment = completeEnvironment()
        environment[DiscourseQualificationConfiguration.reportKey] = "../report.json"
        #expect(throws: TranslationQualificationError.self) {
            _ = try DiscourseQualificationConfiguration.load(environment)
        }
    }

    @Test func completeEnvironmentLoadsExactInputs() throws {
        let loaded = try DiscourseQualificationConfiguration.load(completeEnvironment())
        let configuration = try #require(loaded)
        #expect(configuration.reportFilename == "report.json")
        #expect(configuration.manifestURL.path == "/private/manifest.json")
        #expect(configuration.workspaceRoot.path == "/private/workspace")
    }

    private func completeEnvironment() -> [String: String] {
        [
            DiscourseQualificationConfiguration.manifestKey: "/private/manifest.json",
            DiscourseQualificationConfiguration.reportKey: "report.json",
            DiscourseQualificationConfiguration.workspaceKey: "/private/workspace",
        ]
    }
}
