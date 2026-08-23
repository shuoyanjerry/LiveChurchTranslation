/// Resource ceilings applied before allocating model-input PCM.
public enum ASRQualificationResourceLimits {
    /// At 16 kHz this permits up to 20 seconds of synthetic silence.
    public static let maximumSyntheticPaddingSamples = 320_000

    /// At 16 kHz this permits up to 120 seconds (about 7.3 MiB) of Float32 PCM.
    public static let maximumLoadedSegmentSamples = 1_920_000

    /// Caps all returned segment arrays for one clip at about 61 MiB of Float32 PCM.
    public static let maximumLoadedClipSamples = 16_000_000
}
