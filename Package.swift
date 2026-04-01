// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WisprLocal",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "ASRCore", targets: ["ASRCore"]),
        .library(name: "AudioCore", targets: ["AudioCore"]),
        .library(name: "SessionCore", targets: ["SessionCore"]),
        .library(name: "SnippetCore", targets: ["SnippetCore"]),
        .library(name: "TextTargetMac", targets: ["TextTargetMac"]),
        .library(name: "CapabilityCore", targets: ["CapabilityCore"]),
        .library(name: "LicenseCore", targets: ["LicenseCore"])
    ],
    targets: [
        .target(
            name: "ASRCore"
        ),
        .target(
            name: "AudioCore",
            dependencies: ["ASRCore"]
        ),
        .target(
            name: "SnippetCore"
        ),
        .target(
            name: "SessionCore",
            dependencies: ["SnippetCore"]
        ),
        .target(
            name: "TextTargetMac"
        ),
        .target(
            name: "CapabilityCore"
        ),
        .target(
            name: "LicenseCore"
        ),
        .testTarget(
            name: "ASRCoreTests",
            dependencies: ["ASRCore"]
        ),
        .testTarget(
            name: "SnippetCoreTests",
            dependencies: ["SnippetCore"]
        ),
        .testTarget(
            name: "SessionCoreTests",
            dependencies: ["SessionCore"]
        ),
        .testTarget(
            name: "LicenseCoreTests",
            dependencies: ["LicenseCore"]
        ),
        .testTarget(
            name: "CapabilityCoreTests",
            dependencies: ["CapabilityCore"]
        ),
        .testTarget(
            name: "DocsContractTests",
            dependencies: []
        )
    ]
)
