/// Aggressiveness profiles supplied by the upstream WebRTC VAD.
public enum WebRTCVADMode: Int32, Sendable, CaseIterable {
    case quality = 0
    case lowBitrate = 1
    case aggressive = 2
    case veryAggressive = 3
}
