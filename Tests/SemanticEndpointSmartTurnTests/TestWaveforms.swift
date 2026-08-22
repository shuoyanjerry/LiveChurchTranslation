import Foundation

enum TestWaveforms {
    static let sampleRate = 16_000

    static func silence() -> [Float] {
        [Float](repeating: 0, count: sampleRate)
    }

    static func sine() -> [Float] {
        (0..<(2 * sampleRate)).map { index in
            Float(0.25 * sin(2 * .pi * 440 * Double(index) / Double(sampleRate)))
        }
    }

    static func mixedSpeechLike() -> [Float] {
        (0..<(10 * sampleRate)).map { index in
            let time = Double(index) / Double(sampleRate)
            if time < 2 { return 0.9 }
            if (4.15..<4.55).contains(time) || (7.20..<7.48).contains(time) { return 0 }
            let carrier =
                0.16 * sin(2 * .pi * ((150 * time) + (18 * time * time)))
                + 0.10 * sin(2 * .pi * 420 * time)
                + 0.06 * sin(2 * .pi * 910 * time)
            let envelope = 0.35 + (0.65 * pow(sin(.pi * 2.7 * time), 2))
            return Float(carrier * envelope)
        }
    }
}
