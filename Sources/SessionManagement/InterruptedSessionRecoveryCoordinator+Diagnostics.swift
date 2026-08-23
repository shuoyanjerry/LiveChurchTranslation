import DiagnosticsAPI

extension InterruptedSessionRecoveryCoordinator {
    func record(
        _ issue: InterruptedSessionRecoveryIssue,
        severity: DiagnosticSeverity
    ) async {
        let measurements: [String: Double] =
            issue.sessionID == nil ? [:] : ["session_scoped": 1]
        await diagnostics.record(
            DiagnosticEvent(
                severity: severity,
                component: "StartupRecovery",
                message: diagnosticMessage(for: issue),
                measurements: measurements
            )
        )
    }

    private func diagnosticMessage(for issue: InterruptedSessionRecoveryIssue) -> String {
        let stageName =
            switch issue.stage {
            case .scan: "扫描"
            case .recording: "录音"
            case .transcript: "听抄稿"
            }
        var base = "[\(issue.code.rawValue)] \(stageName)：\(issue.message)"
        if let sessionID = issue.sessionID {
            base += " 会议标识：\(sessionID.uuidString)。"
        }
        guard let detail = issue.technicalDetail, !detail.isEmpty else { return base }
        return "\(base) 技术详情：\(detail)"
    }
}
