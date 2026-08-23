import Foundation

enum V3SelectedVADQualificationHarness {
    static func run(
        inputs: V3SelectedVADInputs
    ) async throws -> (V3SelectedVADReport, V3SelectedVADFingerprint) {
        let prepared = try V3SelectedVADPreflight().prepare(inputs)
        let attempts = await V3SelectedVADRunner().replay(prepared.tracks)
        let postflight = try V3SelectedVADPreflight().revalidate(prepared, inputs: inputs)
        let report = try V3SelectedVADReportFactory.make(
            prepared: prepared,
            postflight: postflight,
            attempts: attempts
        )
        let outputValues = [inputs.outputURL?.path, inputs.outputURL?.deletingLastPathComponent().path]
            .compactMap { $0 }
        let data = try V3SelectedVADReportCodec.encode(
            report,
            forbiddenValues: prepared.forbiddenValues + outputValues
        )
        let written = try V3SelectedVADPrivateWriter.write(data, inputs: inputs)
        try validateWritten(data, fingerprint: written, inputs: inputs)
        print("V3_SELECTED_VAD_ATTEMPTS=\(report.aggregates.overall.trackAttemptCount)")
        print("V3_SELECTED_VAD_FAILURES=\(report.aggregates.overall.failureCount)")
        print("V3_SELECTED_VAD_REPORT_SHA256=\(written.sha256)")
        return (report, written)
    }

    private static func validateWritten(
        _ expected: Data,
        fingerprint: V3SelectedVADFingerprint,
        inputs: V3SelectedVADInputs
    ) throws {
        guard let outputURL = inputs.outputURL,
            try Data(contentsOf: outputURL, options: [.uncached]) == expected,
            try V3SelectedVADHashing.fingerprint(outputURL) == fingerprint,
            try permissions(outputURL) == 0o600,
            try permissions(outputURL.deletingLastPathComponent()) == 0o700,
            try permissions(outputURL.deletingLastPathComponent().deletingLastPathComponent())
                == 0o700
        else { throw V3SelectedVADError.storageFailure }
    }

    private static func permissions(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let value = attributes[.posixPermissions] as? NSNumber else {
            throw V3SelectedVADError.storageFailure
        }
        return value.intValue
    }
}
