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
    dependencies: [Target.Dependency],
    exclude: [String] = []
) -> Target {
    .testTarget(
        name: name,
        dependencies: dependencies,
        exclude: exclude,
        swiftSettings: strict
    )
}

let sherpaOnnx: Target.Dependency = .product(
    name: "sherpa-onnx",
    package: "sherpa-onnx"
)

let package = Package(
    name: "LiveChurchTranslation",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ChurchTranslatorApp", targets: ["ChurchTranslatorApp"]),
        .executable(name: "LiveChurchTranslation", targets: ["ChurchTranslatorCLI"]),
        .executable(
            name: "scripture-qualification-tool",
            targets: ["ScriptureQualificationTool"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/k2-fsa/sherpa-onnx.git",
            exact: "1.13.6"
        )
    ],
    targets: [
        target("AudioCaptureAPI"),
        target("RecordingAPI", dependencies: ["AudioCaptureAPI"]),
        target("AudioProcessingAPI", dependencies: ["AudioCaptureAPI"]),
        target("VADAPI", dependencies: ["AudioProcessingAPI"]),
        target("UtteranceRecoveryAPI", dependencies: ["VADAPI"]),
        target("ASRAPI", dependencies: ["VADAPI"]),
        target("ASRNormalizationAPI"),
        target("ASRQualificationSupport"),
        target("ScriptureAPI"),
        target("ScriptureQualificationSupport", dependencies: ["ScriptureAPI"]),
        target("DiscourseResolutionAPI"),
        target("TranslationAPI"),
        target("TranslationQualificationSupport"),
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
        target("AudioFileAVFoundation", dependencies: ["AudioCaptureAPI"]),
        target(
            "RecordingFileSystem",
            dependencies: ["AudioCaptureAPI", "RecordingAPI"]
        ),
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
        target(
            "UtteranceRecoveryFileSystem",
            dependencies: ["UtteranceRecoveryAPI", "VADAPI"]
        ),
        target(
            "ASRQwen3",
            dependencies: ["ASRAPI", "ModelRuntimeAPI", sherpaOnnx]
        ),
        target(
            "ASRFunASRNano",
            dependencies: ["ASRAPI", sherpaOnnx]
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
        target(
            "TranslationHyMT2",
            dependencies: ["ModelRuntimeAPI", "ScriptureAPI", "TranslationAPI"]
        ),
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
                "RecordingAPI", "TranscriptAPI", "TranslationAPI", "VADAPI",
                "UtteranceRecoveryAPI",
            ]
        ),
        target("UIDesignSystem"),
        target(
            "LiveReader",
            dependencies: [
                "AudioCaptureAPI", "GlossaryAPI", "ModelRuntimeAPI",
                "PersistenceAPI", "RemoteSharingFeatureAPI", "SessionManagementAPI", "SettingsAPI",
                "ScriptureAPI", "TranscriptAPI", "UIDesignSystem", "UtteranceRecoveryAPI",
            ]
        ),
        target(
            "ChurchTranslatorApp",
            dependencies: [
                "ASRNormalizationCore", "ASRQwen3", "AudioCaptureAVFoundation",
                "AudioFileAVFoundation", "AudioProcessingCore", "DiagnosticsCore", "GlossaryCore",
                "GlossaryFileSystem", "LiveReader", "LoggingOSLog", "ModelDownloadAPI",
                "ModelDownloadHTTP",
                "ModelRuntimeAPI", "ModelRuntimeCore", "PersistenceFileSystem",
                "RemoteControlCore", "RemoteControlSessionAdapter", "RemoteDiscoveryBonjour",
                "RemotePairingCore", "RemoteProjectionCore", "RemoteProjectionSessionAdapter",
                "RecordingFileSystem",
                "RemoteSharingFeature", "RemoteSharingFeatureAPI", "RemoteTransportAPI",
                "RemoteTransportNetwork", "RemoteWebAssets", "SessionManagement", "SettingsAPI",
                "SettingsUserDefaults", "TranscriptCore", "TranslationHyMT2", "VADCore",
                "DiscourseResolutionCore", "UtteranceRecoveryFileSystem", "VADWebRTC",
            ]
        ),
        .executableTarget(
            name: "ChurchTranslatorCLI",
            dependencies: ["ChurchTranslatorApp"],
            swiftSettings: strict
        ),
        .executableTarget(
            name: "ScriptureQualificationTool",
            dependencies: ["ScriptureQualificationSupport"],
            swiftSettings: strict
        ),
        test("AudioProcessingCoreTests", dependencies: ["AudioCaptureAPI", "AudioProcessingCore"]),
        test(
            "AudioFileAVFoundationTests",
            dependencies: ["AudioCaptureAPI", "AudioFileAVFoundation"]
        ),
        test(
            "RecordingFileSystemTests",
            dependencies: ["AudioCaptureAPI", "RecordingAPI", "RecordingFileSystem"]
        ),
        test(
            "VADCoreTests",
            dependencies: ["AudioProcessingAPI", "VADCore", "VADWebRTC"]
        ),
        .testTarget(
            name: "VADEndpointBenchmarkTests",
            dependencies: ["AudioProcessingAPI", "VADAPI", "VADCore", "VADWebRTC"],
            exclude: ["README.md"],
            swiftSettings: strict
        ),
        test("VADWebRTCTests", dependencies: ["VADWebRTC"]),
        .testTarget(
            name: "ASRQwen3Tests",
            dependencies: [
                "ASRAPI", "ASRNormalizationAPI", "ASRNormalizationCore",
                "ASRQualificationSupport", "ASRQwen3", "AudioCaptureAPI",
                "AudioFileAVFoundation", "AudioProcessingCore", "GlossaryAPI",
                "ScriptureAPI", "ScriptureQualificationSupport", "SessionManagement",
                "SettingsAPI", "TranslationAPI", "TranslationHyMT2", "VADAPI", sherpaOnnx,
            ],
            exclude: ["README.md"],
            swiftSettings: strict
        ),
        test(
            "ASRFunASRNanoTests",
            dependencies: [
                "ASRAPI", "ASRFunASRNano", "ASRNormalizationAPI",
                "ASRNormalizationCore", "ASRQualificationSupport", "ASRQwen3",
                "VADAPI", sherpaOnnx,
            ]
        ),
        test(
            "ASRNormalizationCoreTests",
            dependencies: ["ASRNormalizationAPI", "ASRNormalizationCore"]
        ),
        test(
            "ASRQualificationSupportTests",
            dependencies: ["ASRQualificationSupport"]
        ),
        test(
            "ScriptureQualificationSupportTests",
            dependencies: ["ScriptureAPI", "ScriptureQualificationSupport"]
        ),
        .testTarget(
            name: "ASRQualificationManifestToolTests",
            dependencies: ["ASRQualificationSupport"],
            exclude: ["README.md"],
            swiftSettings: strict
        ),
        .testTarget(
            name: "DiscourseResolutionCoreTests",
            dependencies: [
                "DiscourseResolutionAPI", "DiscourseResolutionCore",
                "TranslationQualificationSupport",
            ],
            exclude: ["README.md"],
            swiftSettings: strict
        ),
        test("GlossaryCoreTests", dependencies: ["GlossaryCore"]),
        test(
            "TranscriptCoreTests",
            dependencies: ["ASRAPI", "TranscriptAPI", "TranscriptCore", "TranslationAPI"]
        ),
        test("PersistenceFileSystemTests", dependencies: ["PersistenceFileSystem", "TranscriptAPI"]),
        test("LoggingOSLogTests", dependencies: ["LoggingAPI", "LoggingOSLog"]),
        test(
            "ModelDownloadHTTPTests",
            dependencies: ["ModelDownloadAPI", "ModelDownloadHTTP", "ModelRuntimeAPI"]
        ),
        test(
            "TranslationHyMT2Tests",
            dependencies: [
                "DiscourseResolutionAPI", "DiscourseResolutionCore", "GlossaryAPI",
                "ScriptureAPI", "TranslationAPI", "TranslationHyMT2",
                "TranslationQualificationSupport",
            ],
            exclude: ["README.md"]
        ),
        test(
            "TranslationQualificationSupportTests",
            dependencies: ["TranslationQualificationSupport"]
        ),
        test(
            "LiveReaderTests",
            dependencies: ["LiveReader", "RemoteSharingFeatureAPI", "ScriptureAPI"]
        ),
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
                "RecordingAPI", "TranscriptAPI", "TranscriptCore", "TranslationAPI", "VADAPI",
                "UtteranceRecoveryAPI",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
