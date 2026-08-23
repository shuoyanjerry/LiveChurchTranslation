enum NegationPolicyV2ShadowTestFixture {
    static func report() throws -> NegationPolicyV2ShadowReport {
        let all = try NegationPolicyV2ShadowCounts.aggregate(
            Array(repeating: .requiresOvertCue(count: 1), count: 144)
        )
        let success = try NegationPolicyV2ShadowCounts.aggregate(
            Array(repeating: .requiresOvertCue(count: 1), count: 109)
        )
        let failure = try NegationPolicyV2ShadowCounts.aggregate(
            Array(repeating: .requiresOvertCue(count: 1), count: 35)
        )
        return NegationPolicyV2ShadowReport(
            schemaVersion: 1,
            manifestSHA256: HyMTQualificationConfiguration.manifestSHA256,
            classifiedReportSHA256: NegationPolicyV2ShadowIdentity.classifiedReportSHA256,
            policySHA256: String(repeating: "a", count: 64),
            configurationSHA256: String(repeating: "b", count: 64),
            totalSegmentCount: 144,
            classifiedSuccessCount: 109,
            classifiedFailureCount: 35,
            allSegmentsSource: all,
            successfulAttemptsFull: success,
            failedAttemptsSource: failure,
            acceptedUnsafeTargetUnicodeCount: 0
        )
    }
}
