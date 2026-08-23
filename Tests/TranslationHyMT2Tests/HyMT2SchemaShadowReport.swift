import Foundation

enum HyMT2SchemaShadowReportError: Error {
    case invalid
}

enum HyMT2SchemaShadowReportWriter {
    static func write(_ report: HyMT2SchemaShadowReport, to url: URL) throws {
        let data = try encoded(report)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    static func encoded(_ report: HyMT2SchemaShadowReport) throws -> Data {
        try validate(report)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(report)
    }

    private static func validate(_ report: HyMT2SchemaShadowReport) throws {
        guard report.schemaVersion == 1,
            [report.modelSHA256, report.helperSHA256, report.configurationSHA256]
                .allSatisfy(isSHA256),
            report.backgroundLoad == "idle-sibling-q8-resident",
            !report.latencyControlled,
            probeIsValid(report.probe), hasCompleteMatrix(report.results)
        else {
            throw HyMT2SchemaShadowReportError.invalid
        }
        for result in report.results {
            guard isSafeID(result.fixtureID), (1...4).contains(result.occurrenceCount),
                isValidLatency(result.latencyMilliseconds),
                result.schemaSHA256.map(isSHA256) ?? true,
                result.outputSHA256.map(isSHA256) ?? true,
                hasValidVariantSchema(result), hasConsistentOutcome(result)
            else {
                throw HyMT2SchemaShadowReportError.invalid
            }
        }
    }

    private static func probeIsValid(_ probe: HyMT2SchemaShadowProbeResult) -> Bool {
        probe.status == .passed && probe.failureCode == nil
            && isValidLatency(probe.latencyMilliseconds)
            && probe.outputSHA256.map(isSHA256) == true
            && isSHA256(probe.schemaSHA256)
    }

    private static func hasValidVariantSchema(_ result: HyMT2SchemaShadowResult) -> Bool {
        switch result.variant {
        case .current: result.schemaSHA256 == nil
        case .schema: result.schemaSHA256 != nil
        }
    }

    private static func hasConsistentOutcome(_ result: HyMT2SchemaShadowResult) -> Bool {
        switch (result.status, result.failureCode, result.outputSHA256) {
        case (.passed, nil, .some): true
        case (.failed, .some(.transport), nil), (.failed, .some(.currentProtocol), nil): true
        case (.failed, .some, .some): true
        default: false
        }
    }

    private static func hasCompleteMatrix(_ results: [HyMT2SchemaShadowResult]) -> Bool {
        let expected = Set(
            HyMT2SchemaShadowFixtures.negation.flatMap { fixture in
                HyMT2SchemaShadowVariant.allCases.map {
                    MatrixKey(
                        family: .negation,
                        fixtureID: fixture.identifier,
                        variant: $0,
                        occurrenceCount: fixture.base.functionalCues.count
                    )
                }
            }
                + HyMT2SchemaShadowFixtures.pronoun.flatMap { fixture in
                    HyMT2SchemaShadowVariant.allCases.map {
                        MatrixKey(
                            family: .pronoun,
                            fixtureID: fixture.base.name,
                            variant: $0,
                            occurrenceCount: fixture.base.references.count
                        )
                    }
                }
        )
        let actual = results.map {
            MatrixKey(
                family: $0.family,
                fixtureID: $0.fixtureID,
                variant: $0.variant,
                occurrenceCount: $0.occurrenceCount
            )
        }
        return actual.count == expected.count && Set(actual) == expected
    }

    private static func isValidLatency(_ value: Double) -> Bool {
        value.isFinite && value >= 0
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func isSafeID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 64
            && value.allSatisfy {
                $0.isLowercase || $0.isNumber || $0 == "." || $0 == "-"
            }
    }

    private struct MatrixKey: Hashable {
        let family: HyMT2SchemaShadowFamily
        let fixtureID: String
        let variant: HyMT2SchemaShadowVariant
        let occurrenceCount: Int
    }
}
