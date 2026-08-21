// swift-tools-version: 6.1

import PackageDescription
import Foundation

let strict: [SwiftSetting] = [
    .unsafeFlags(["-warnings-as-errors"])
]

func target(
    _ name: String,
    dependencies: [Target.Dependency] = []
) -> Target {
    let readmePath = "Sources/\(name)/README.md"
    let excluded = FileManager.default.fileExists(atPath: readmePath) ? ["README.md"] : []
    return .target(
        name: name,
        dependencies: dependencies,
        exclude: excluded,
        swiftSettings: strict
    )
}

func test(
    _ name: String,
    dependencies: [Target.Dependency]
) -> Target {
    .testTarget(name: name, dependencies: dependencies, swiftSettings: strict)
}

let sherpaOnnx: Target.Dependency = .product(
    name: "sherpa-onnx",
    package: "sherpa-onnx"
)

let package = Package(
    name: "LiveChurchTranslation",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "LiveChurchTranslation", targets: ["ChurchTranslatorApp"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/k2-fsa/sherpa-onnx.git",
            exact: "1.13.6"
        )
    ],
    targets: [
        target("AudioCaptureAPI"),
        target("AudioProcessingAPI", dependencies: ["AudioCaptureAPI"]),
        target("VADAPI", dependencies: ["AudioProcessingAPI"]),
        target("ASRAPI", dependencies: ["VADAPI"]),
        target("ASRNormalizationAPI"),
        target("TranslationAPI"),
        target("GlossaryAPI"),
        target("ModelRuntimeAPI"),
        target("ModelDownloadAPI", dependencies: ["ModelRuntimeAPI"]),
        target("TranscriptAPI", dependencies: ["ASRAPI", "TranslationAPI"]),
        target("PersistenceAPI", dependencies: ["TranscriptAPI"]),
        target("SettingsAPI"),
        target("LoggingAPI"),
        target("DiagnosticsAPI"),
        target(
            "SessionManagementAPI",
            dependencies: [
                "AudioCaptureAPI", "DiagnosticsAPI", "ModelRuntimeAPI", "TranscriptAPI",
            ]
        ),
        target("AudioCaptureAVFoundation", dependencies: ["AudioCaptureAPI"]),
        target("AudioProcessingCore", dependencies: ["AudioProcessingAPI"]),
        target("VADCore", dependencies: ["VADAPI"]),
        target(
            "ASRQwen3",
            dependencies: ["ASRAPI", "ModelRuntimeAPI", sherpaOnnx]
        ),
        target("ASRNormalizationCore", dependencies: ["ASRNormalizationAPI"]),
        target(
            "TranslationApple",
            dependencies: ["TranslationAPI", "ModelRuntimeAPI"]
        ),
        target("TranslationHyMT2", dependencies: ["TranslationAPI"]),
        target("GlossaryCore", dependencies: ["GlossaryAPI"]),
        target("GlossaryFileSystem", dependencies: ["GlossaryAPI"]),
        target("ModelRuntimeCore", dependencies: ["ModelRuntimeAPI"]),
        target(
            "ModelDownloadHTTP",
            dependencies: ["ModelDownloadAPI", "ModelRuntimeAPI"]
        ),
        target("TranscriptCore", dependencies: ["TranscriptAPI"]),
        target("PersistenceFileSystem", dependencies: ["PersistenceAPI"]),
        target("SettingsUserDefaults", dependencies: ["SettingsAPI"]),
        target("LoggingOSLog", dependencies: ["LoggingAPI"]),
        target("DiagnosticsCore", dependencies: ["DiagnosticsAPI", "LoggingAPI"]),
        target(
            "SessionManagement",
            dependencies: [
                "ASRAPI", "ASRNormalizationAPI", "AudioCaptureAPI", "AudioProcessingAPI",
                "DiagnosticsAPI", "GlossaryAPI", "LoggingAPI", "ModelDownloadAPI",
                "ModelRuntimeAPI", "PersistenceAPI", "SessionManagementAPI", "SettingsAPI",
                "TranscriptAPI", "TranslationAPI", "VADAPI",
            ]
        ),
        target("UIDesignSystem"),
        target(
            "LiveReader",
            dependencies: [
                "AudioCaptureAPI", "GlossaryAPI", "ModelRuntimeAPI",
                "SessionManagementAPI", "SettingsAPI", "TranscriptAPI", "UIDesignSystem",
            ]
        ),
        .executableTarget(
            name: "ChurchTranslatorApp",
            dependencies: [
                "ASRNormalizationCore", "ASRQwen3", "AudioCaptureAVFoundation",
                "AudioProcessingCore", "DiagnosticsCore", "GlossaryCore",
                "GlossaryFileSystem", "LiveReader", "LoggingOSLog", "ModelDownloadHTTP",
                "ModelRuntimeAPI", "ModelRuntimeCore", "PersistenceFileSystem",
                "SessionManagement", "SettingsUserDefaults", "TranscriptCore",
                "TranslationHyMT2", "VADCore",
            ],
            swiftSettings: strict
        ),
        test("AudioProcessingCoreTests", dependencies: ["AudioCaptureAPI", "AudioProcessingCore"]),
        test("VADCoreTests", dependencies: ["AudioProcessingAPI", "VADCore"]),
        test(
            "ASRQwen3Tests",
            dependencies: [
                "ASRAPI", "ASRNormalizationCore", "ASRQwen3", "VADAPI", sherpaOnnx,
            ]
        ),
        test(
            "ASRNormalizationCoreTests",
            dependencies: ["ASRNormalizationAPI", "ASRNormalizationCore"]
        ),
        test("GlossaryCoreTests", dependencies: ["GlossaryCore"]),
        test("TranscriptCoreTests", dependencies: ["ASRAPI", "TranscriptCore", "TranslationAPI"]),
        test("PersistenceFileSystemTests", dependencies: ["PersistenceFileSystem", "TranscriptAPI"]),
        test(
            "ModelDownloadHTTPTests",
            dependencies: ["ModelDownloadAPI", "ModelDownloadHTTP", "ModelRuntimeAPI"]
        ),
        test(
            "TranslationHyMT2Tests",
            dependencies: ["TranslationAPI", "TranslationHyMT2"]
        ),
        test("LiveReaderTests", dependencies: ["LiveReader"]),
        test(
            "SessionManagementTests",
            dependencies: [
                "ASRAPI", "ASRNormalizationCore", "AudioCaptureAPI", "AudioProcessingAPI",
                "DiagnosticsAPI", "GlossaryAPI", "LoggingAPI", "ModelDownloadAPI",
                "ModelRuntimeAPI", "PersistenceAPI", "SessionManagement", "SettingsAPI",
                "TranscriptAPI", "TranscriptCore", "TranslationAPI", "VADAPI",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
