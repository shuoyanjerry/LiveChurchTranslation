import Foundation
import Testing

@Suite struct ScriptureQualificationConfigTests {
    @Test("requires aggregate-only mode and the dedicated report boundary")
    func acceptsCompleteEnvironment() throws {
        let workspace = URL(fileURLWithPath: "/tmp/scripture-workspace", isDirectory: true)
        let configuration = try ScriptureModelQualificationConfiguration.load(
            environment: environment(workspace: workspace),
            workspaceRoot: workspace
        )

        #expect(configuration.manifestSHA256 == String(repeating: "a", count: 64))
        #expect(configuration.phase == .development)
        #expect(
            configuration.reportURL.path
                == "/tmp/scripture-workspace/.artifacts/scripture-qualification-reports/report.json"
        )
    }

    @Test("rejects a report outside the aggregate-only report boundary")
    func rejectsOutsideReport() {
        let workspace = URL(fileURLWithPath: "/tmp/scripture-workspace", isDirectory: true)
        var values = environment(workspace: workspace)
        values["SCRIPTURE_QUALIFICATION_REPORT"] = "/tmp/report.json"

        #expect(throws: ScriptureModelQualificationError.self) {
            try ScriptureModelQualificationConfiguration.load(
                environment: values,
                workspaceRoot: workspace
            )
        }
    }

    @Test("an absent corpus skips while any partial request fails closed")
    func requestDetection() {
        #expect(!ScriptureModelQualificationConfiguration.isRequested([:]))
        #expect(
            ScriptureModelQualificationConfiguration.isRequested([
                "SCRIPTURE_QUALIFICATION_ROOT": "/tmp/corpus"
            ])
        )
    }

    @Test("requires an explicit development or sealed phase")
    func rejectsUnknownPhase() {
        let workspace = URL(fileURLWithPath: "/tmp/scripture-workspace", isDirectory: true)
        var values = environment(workspace: workspace)
        values["SCRIPTURE_QUALIFICATION_PHASE"] = "combined"

        #expect(throws: ScriptureModelQualificationError.self) {
            try ScriptureModelQualificationConfiguration.load(
                environment: values,
                workspaceRoot: workspace
            )
        }
    }

    private func environment(workspace: URL) -> [String: String] {
        [
            "SCRIPTURE_QUALIFICATION_AGGREGATE_ONLY": "1",
            "SCRIPTURE_QUALIFICATION_PHASE": "development",
            "SCRIPTURE_QUALIFICATION_ROOT": "/tmp/private-corpus",
            "SCRIPTURE_QUALIFICATION_MANIFEST": "/tmp/private-corpus/manifest.json",
            "SCRIPTURE_QUALIFICATION_MANIFEST_SHA256": String(repeating: "a", count: 64),
            "SCRIPTURE_QUALIFICATION_REPORT": workspace.appendingPathComponent(
                ".artifacts/scripture-qualification-reports/report.json"
            ).path,
            "QWEN_MODEL_DIR": "/tmp/qwen",
            "HYMT_MODEL_DIR": "/tmp/hymt",
            "HYMT_LLAMA_SERVER": "/tmp/llama-server",
        ]
    }
}
