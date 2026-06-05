// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CommenterIOS",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CommenterDomain", targets: ["CommenterDomain"]),
        .library(name: "CommentEngine", targets: ["CommentEngine"]),
        .library(name: "CommenterPersistence", targets: ["CommenterPersistence"]),
        .library(name: "CommenterImportExport", targets: ["CommenterImportExport"]),
        .library(name: "CommenterReportSafety", targets: ["CommenterReportSafety"]),
        .library(name: "CommenterAI", targets: ["CommenterAI"]),
        .library(name: "CommenterAppIntents", targets: ["CommenterAppIntents"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "CommenterAITestSupport", targets: ["CommenterAITestSupport"]),
        .library(name: "CommenterTestSupport", targets: ["CommenterTestSupport"]),
        .executable(name: "CommenterIOSApp", targets: ["CommenterIOSApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", .upToNextMinor(from: "0.14.1")),
        .package(url: "https://github.com/CoreOffice/OLEKit.git", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        .package(url: "https://github.com/dehesa/CodableCSV.git", from: "0.6.7"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0")
    ],
    targets: [
        .target(name: "CommenterDomain"),
        .target(
            name: "CommentEngine",
            dependencies: ["CommenterDomain"],
            resources: [.copy("Resources/comment-engine.json")]
        ),
        .target(
            name: "CommenterPersistence",
            dependencies: [
                "CommenterDomain",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .target(
            name: "CommenterImportExport",
            dependencies: [
                "CommenterDomain",
                "CommentEngine",
                "CommenterPersistence",
                .product(name: "CodableCSV", package: "CodableCSV"),
                .product(name: "CoreXLSX", package: "CoreXLSX"),
                .product(name: "OLEKit", package: "OLEKit"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .target(
            name: "CommenterReportSafety",
            dependencies: ["CommenterDomain"]
        ),
        .target(
            name: "CommenterAI",
            dependencies: ["CommenterDomain", "CommenterReportSafety"]
        ),
        .target(
            name: "CommenterAppIntents",
            dependencies: ["CommenterDomain"]
        ),
        .target(name: "DesignSystem"),
        .target(
            name: "AppFeature",
            dependencies: [
                "CommenterDomain",
                "CommentEngine",
                "CommenterPersistence",
                "CommenterImportExport",
                "CommenterReportSafety",
                "CommenterAI",
                "DesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "CommenterTestSupport",
            dependencies: ["CommenterDomain", "CommentEngine"]
        ),
        .target(
            name: "CommenterAITestSupport",
            dependencies: ["CommenterAI", "CommenterDomain", "CommenterReportSafety"]
        ),
        .executableTarget(
            name: "CommenterIOSApp",
            dependencies: ["AppFeature"],
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "CommenterDomainTests",
            dependencies: ["CommenterDomain"]
        ),
        .testTarget(
            name: "CommentEngineTests",
            dependencies: ["CommentEngine", "CommenterDomain", "CommenterTestSupport"]
        ),
        .testTarget(
            name: "CommenterImportExportTests",
            dependencies: ["CommenterImportExport", "CommenterPersistence", "CommentEngine", "CommenterDomain"]
        ),
        .testTarget(
            name: "CommenterReportSafetyTests",
            dependencies: ["CommenterReportSafety", "CommenterDomain"]
        ),
        .testTarget(
            name: "CommenterAITests",
            dependencies: ["CommenterAI", "CommenterAITestSupport", "CommenterDomain"]
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: [
                "AppFeature",
                "CommenterAI",
                "CommenterAITestSupport",
                "CommentEngine",
                "CommenterDomain",
                "CommenterImportExport",
                "CommenterReportSafety",
                "CommenterPersistence",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .testTarget(
            name: "CommenterPersistenceTests",
            dependencies: ["CommenterPersistence", "CommenterDomain"]
        )
    ]
)
