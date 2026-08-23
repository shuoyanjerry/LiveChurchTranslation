enum FunASRNanoInputGuard {
    static func containsSpeech(_ samples: [Float], minimumRMS: Float) -> Bool {
        guard !samples.isEmpty else { return false }
        let squaredEnergy = samples.reduce(0.0) { partial, sample in
            partial + Double(sample * sample)
        }
        let rms = Float((squaredEnergy / Double(samples.count)).squareRoot())
        return rms >= minimumRMS
    }
}
