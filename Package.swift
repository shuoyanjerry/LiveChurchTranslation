// swift-tools-version: 6.1

import PackageDescription

let strict: [SwiftSetting] = [
    .unsafeFlags(["-warnings-as-errors"])
]

func target(
    _ name: String,
    dependencies: [Target.Dependency] = []
) -> Target {
    return .target(
        name: name,
        dependencies: dependencies,
        exclude: ["README.md"],
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

let onnxRuntime: Target.Dependency = .product(
    name: "OnnxRuntimeKit",
    package: "onnxruntime-libs"
)

let package = Package(
    name: "LiveChurchTranslation",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "LiveChurchTranslation", targets: ["ChurchTranslatorApp"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/csukuangfj/onnxruntime-libs",
            exact: "1.27.1"
        ),
        .package(
            url: "https://github.com/k2-fsa/sherpa-onnx.git",
            exact: "1.13.6"
        ),
    ],
    targets: [
        target("AudioCaptureAPI"),
        target("AudioProcessingAPI", dependencies: ["AudioCaptureAPI"]),
        target("VADAPI", dependencies: ["AudioProcessingAPI"]),
        target("SemanticEndpointAPI"),
        target("UtteranceRecoveryAPI", dependencies: ["VADAPI"]),
        target("ASRAPI", dependencies: ["VADAPI"]),
        target("ASRNormalizationAPI"),
        target("DiscourseResolutionAPI"),
        target("TranslationAPI"),
        target("GlossaryAPI"),
        target("ModelRuntimeAPI"),
        target("ModelDownloadAPI", dependencies: ["ModelRuntimeAPI"]),
        target("TranscriptAPI", dependencies: ["ASRAPI", "TranslationAPI"]),
        target("PersistenceAPI", dependencies: ["TranscriptAPI"]),
        target("SettingsAPI"),
        target("LoggingAPI"),
        target("DiagnosticsAPI"),
        target("RemoteSharingAPI"),
        target("RemoteSharingFeatureAPI"),
        target("RemoteControlAPI", dependencies: ["RemoteSharingAPI"]),
        target("RemotePairingAPI", dependencies: ["RemoteSharingAPI"]),
        target("RemoteWebAssetsAPI"),
        target("RemoteDiscoveryAPI"),
        target("RemoteTransportAPI", dependencies: ["RemoteDiscoveryAPI"]),
        target(
            "SessionManagementAPI",
            dependencies: [
                "AudioCaptureAPI", "DiagnosticsAPI", "ModelRuntimeAPI", "TranscriptAPI",
            ]
        ),
        target("AudioCaptureAVFoundation", dependencies: ["AudioCaptureAPI"]),
        target("AudioProcessingCore", dependencies: ["AudioProcessingAPI"]),
        target("VADCore", dependencies: ["VADAPI"]),
        .target(
            name: "WebRTCVADC",
            exclude: [
                "NOTICE", "README.md", "Vendor/libfvad/AUTHORS", "Vendor/libfvad/LICENSE",
                "Vendor/libfvad/PATENTS", "Vendor/libfvad/src/CMakeLists.txt",
                "Vendor/libfvad/src/Makefile.am",
            ],
            sources: ["Vendor/libfvad/src"],
            publicHeadersPath: "Vendor/libfvad/include",
            cSettings: [
                .unsafeFlags(["-std=c11", "-Wall", "-Wextra", "-Wpedantic", "-Werror"])
            ]
        ),
        .target(
            name: "VADWebRTC",
            dependencies: ["VADAPI", "WebRTCVADC"],
            exclude: ["NOTICE", "README.md"],
            swiftSettings: strict
        ),
        .target(
            name: "SmartTurnOnnxRuntimeC",
            dependencies: [onnxRuntime],
            exclude: ["README.md"],
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags([
                    "-std=c11", "-Wall", "-Wextra", "-Wpedantic", "-Werror",
                    "-Wno-incomplete-umbrella",
                ])
            ]
        ),
        .target(
            name: "SemanticEndpointSmartTurn",
            dependencies: ["SemanticEndpointAPI", "SmartTurnOnnxRuntimeC"],
            exclude: ["NOTICE", "README.md"],
            swiftSettings: strict,
            linkerSettings: [.linkedFramework("Accelerate")]
        ),
        target(
            "UtteranceRecoveryFileSystem",
            dependencies: ["UtteranceRecoveryAPI", "VADAPI"]
        ),
        target(
            "ASRQwen3",
            dependencies: ["ASRAPI", "ModelRuntimeAPI", sherpaOnnx]
        ),
        target("ASRNormalizationCore", dependencies: ["ASRNormalizationAPI"]),
        target(
            "DiscourseResolutionCore",
            dependencies: ["DiscourseResolutionAPI"]
        ),
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
            "RemotePairingCore",
            dependencies: ["RemotePairingAPI", "RemoteSharingAPI"]
        ),
        target(
            "RemoteControlCore",
            dependencies: ["RemoteControlAPI", "RemoteSharingAPI"]
        ),
        target(
            "RemoteControlSessionAdapter",
            dependencies: [
                "AudioCaptureAPI", "RemoteControlAPI", "SessionManagementAPI", "SettingsAPI",
            ]
        ),
        target(
            "RemoteSharingFeature",
            dependencies: [
                "RemotePairingAPI", "RemoteSharingAPI", "RemoteSharingFeatureAPI",
                "RemoteTransportAPI",
            ]
        ),
        target("RemoteProjectionCore", dependencies: ["RemoteSharingAPI"]),
        target(
            "RemoteProjectionSessionAdapter",
            dependencies: ["RemoteSharingAPI", "SessionManagementAPI", "TranscriptAPI"]
        ),
        target("RemoteWebAssets", dependencies: ["RemoteWebAssetsAPI"]),
        target("RemoteDiscoveryBonjour", dependencies: ["RemoteDiscoveryAPI"]),
        target(
            "RemoteTransportNetwork",
            dependencies: [
                "RemoteControlAPI", "RemoteDiscoveryAPI", "RemotePairingAPI",
                "RemoteSharingAPI", "RemoteTransportAPI", "RemoteWebAssetsAPI",
            ]
        ),
        target(
            "SessionManagement",
            dependencies: [
                "ASRAPI", "ASRNormalizationAPI", "AudioCaptureAPI", "AudioProcessingAPI",
                "DiagnosticsAPI", "DiscourseResolutionAPI", "GlossaryAPI", "LoggingAPI", "ModelDownloadAPI",
                "ModelRuntimeAPI", "PersistenceAPI", "SessionManagementAPI", "SettingsAPI",
                "TranscriptAPI", "TranslationAPI", "VADAPI",
                "UtteranceRecoveryAPI",
            ]
        ),
        target("UIDesignSystem"),
        target(
            "LiveReader",
            dependencies: [
                "AudioCaptureAPI", "GlossaryAPI", "ModelRuntimeAPI",
                "RemoteSharingFeatureAPI", "SessionManagementAPI", "SettingsAPI",
                "TranscriptAPI", "UIDesignSystem",
            ]
        ),
        .executableTarget(
            name: "ChurchTranslatorApp",
            dependencies: [
                "ASRNormalizationCore", "ASRQwen3", "AudioCaptureAVFoundation",
                "AudioProcessingCore", "DiagnosticsCore", "GlossaryCore",
                "GlossaryFileSystem", "LiveReader", "LoggingOSLog", "ModelDownloadHTTP",
                "ModelRuntimeAPI", "ModelRuntimeCore", "PersistenceFileSystem",
                "RemoteControlCore", "RemoteControlSessionAdapter", "RemoteDiscoveryBonjour",
                "RemotePairingCore", "RemoteProjectionCore", "RemoteProjectionSessionAdapter",
                "RemoteSharingFeature", "RemoteSharingFeatureAPI", "RemoteTransportAPI",
                "RemoteTransportNetwork", "RemoteWebAssets", "SessionManagement", "SettingsAPI",
                "SettingsUserDefaults", "TranscriptCore", "TranslationHyMT2", "VADCore",
                "DiscourseResolutionCore", "UtteranceRecoveryFileSystem", "VADWebRTC",
            ],
            exclude: ["README.md"],
            swiftSettings: strict
        ),
        test("AudioProcessingCoreTests", dependencies: ["AudioCaptureAPI", "AudioProcessingCore"]),
        test(
            "VADCoreTests",
            dependencies: ["AudioProcessingAPI", "VADCore", "VADWebRTC"]
        ),
        test("VADWebRTCTests", dependencies: ["VADWebRTC"]),
        .testTarget(
            name: "SemanticEndpointSmartTurnTests",
            dependencies: ["SemanticEndpointAPI", "SemanticEndpointSmartTurn"],
            resources: [.process("Fixtures")],
            swiftSettings: strict
        ),
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
        .testTarget(
            name: "DiscourseResolutionCoreTests",
            dependencies: ["DiscourseResolutionAPI", "DiscourseResolutionCore"],
            exclude: ["README.md"],
            swiftSettings: strict
        ),
        test("GlossaryCoreTests", dependencies: ["GlossaryCore"]),
        test(
            "TranscriptCoreTests",
            dependencies: ["ASRAPI", "TranscriptAPI", "TranscriptCore", "TranslationAPI"]
        ),
        test("PersistenceFileSystemTests", dependencies: ["PersistenceFileSystem", "TranscriptAPI"]),
        test(
            "ModelDownloadHTTPTests",
            dependencies: ["ModelDownloadAPI", "ModelDownloadHTTP", "ModelRuntimeAPI"]
        ),
        test(
            "TranslationHyMT2Tests",
            dependencies: ["TranslationAPI", "TranslationHyMT2"]
        ),
        test("LiveReaderTests", dependencies: ["LiveReader", "RemoteSharingFeatureAPI"]),
        test(
            "UtteranceRecoveryFileSystemTests",
            dependencies: ["UtteranceRecoveryAPI", "UtteranceRecoveryFileSystem", "VADAPI"]
        ),
        test(
            "RemotePairingCoreTests",
            dependencies: ["RemotePairingAPI", "RemotePairingCore", "RemoteSharingAPI"]
        ),
        test(
            "RemoteControlCoreTests",
            dependencies: ["RemoteControlAPI", "RemoteControlCore", "RemoteSharingAPI"]
        ),
        test(
            "RemoteControlSessionAdapterTests",
            dependencies: [
                "AudioCaptureAPI", "RemoteControlAPI", "RemoteControlSessionAdapter",
                "SessionManagementAPI", "SettingsAPI",
            ]
        ),
        test(
            "RemoteSharingFeatureTests",
            dependencies: [
                "RemoteDiscoveryAPI", "RemotePairingAPI", "RemoteSharingAPI",
                "RemoteSharingFeature", "RemoteSharingFeatureAPI", "RemoteTransportAPI",
            ]
        ),
        test(
            "RemoteProjectionCoreTests",
            dependencies: ["RemoteProjectionCore", "RemoteSharingAPI"]
        ),
        test(
            "RemoteProjectionSessionAdapterTests",
            dependencies: [
                "AudioCaptureAPI", "RemoteProjectionSessionAdapter", "RemoteSharingAPI",
                "SessionManagementAPI", "TranscriptAPI",
            ]
        ),
        test(
            "RemoteWebAssetsTests",
            dependencies: ["RemoteWebAssets", "RemoteWebAssetsAPI"]
        ),
        test(
            "RemoteDiscoveryBonjourTests",
            dependencies: ["RemoteDiscoveryAPI", "RemoteDiscoveryBonjour"]
        ),
        test(
            "RemoteTransportNetworkTests",
            dependencies: [
                "RemoteControlAPI", "RemoteDiscoveryAPI", "RemotePairingAPI",
                "RemoteProjectionCore", "RemoteSharingAPI", "RemoteTransportAPI",
                "RemoteTransportNetwork", "RemoteWebAssets", "RemoteWebAssetsAPI",
            ]
        ),
        test(
            "SessionManagementTests",
            dependencies: [
                "ASRAPI", "ASRNormalizationCore", "AudioCaptureAPI", "AudioProcessingAPI",
                "DiscourseResolutionCore",
                "DiagnosticsAPI", "GlossaryAPI", "LoggingAPI", "ModelDownloadAPI",
                "ModelRuntimeAPI", "PersistenceAPI", "SessionManagement", "SettingsAPI",
                "TranscriptAPI", "TranscriptCore", "TranslationAPI", "VADAPI",
                "UtteranceRecoveryAPI",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
