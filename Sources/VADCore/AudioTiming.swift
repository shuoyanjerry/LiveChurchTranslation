extension Duration {
    var secondsValue: Double {
        let parts = components
        return Double(parts.seconds) + (Double(parts.attoseconds) / 1e18)
    }
}

enum AudioTiming {
    static func sampleCount(for duration: Duration, sampleRate: Double) -> Int {
        max(1, Int((duration.secondsValue * sampleRate).rounded()))
    }

    static func duration(sampleCount: Int, sampleRate: Double) -> Duration {
        .seconds(Double(sampleCount) / sampleRate)
    }
}
