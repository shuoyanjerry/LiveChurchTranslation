import Foundation

extension VADMetricsReport {
    var consoleSummary: String {
        "segments:\(segmentCount),under2:\(underTwoSecondsCount),"
            + "hardProxy:\(forcedHardCutProxyCount),rtf:\(formatted(detectorRTF))"
    }
}

private func formatted(_ value: Double) -> String {
    String(format: "%.6f", value)
}
