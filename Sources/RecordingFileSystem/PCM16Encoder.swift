import Foundation

enum PCM16Encoder {
    static func encode(_ samples: [Float]) -> Data {
        var data = Data(capacity: samples.count * MemoryLayout<Int16>.size)
        for sample in samples {
            let scale: Float = sample < 0 ? 32_768 : 32_767
            var value = Int16(clamping: Int((sample * scale).rounded())).littleEndian
            Swift.withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        return data
    }
}
