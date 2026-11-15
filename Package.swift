// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CommenterIOS",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v27)
    ],
    products: [
        .library(name: "CommenterDomain", targets: ["CommenterDomain"]),
        .library(name: "CommentEngine", targets: ["CommentEngine"]),
        .library(name: "CommenterPersistence", targets: ["CommenterPersistence"]),
        .library(name: "CommenterImportExport", targets: ["CommenterImportExport"]),
        .library(name: "CommenterAI", targets: ["CommenterAI"]),
        .library(name: "CommenterAppIntents", targets: ["CommenterAppIntents"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "AppFeature", targets: ["AppFeature"])
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", .upToNextMinor(from: "0.14.2")),
        .package(url: "https://github.com/CoreOffice/OLEKit.git", .upToNextMinor(from: "0.3.1")),
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMinor(from: "7.12.0")),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMinor(from: "0.9.20")),
        .package(url: "https://github.com/dehesa/CodableCSV.git", .upToNextMinor(from: "0.6.7")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMinor(from: "1.26.2"))
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
        .target(name: "CommenterAI"),
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
                "CommenterAI",
                "CommenterAppIntents",
                "DesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "CommenterTestSupport",
            dependencies: ["CommenterDomain", "CommentEngine"]
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
            name: "AppFeatureTests",
            dependencies: [
                "AppFeature",
                "CommenterAI",
                "CommentEngine",
                "CommenterDomain",
                "CommenterImportExport",
                "CommenterPersistence",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .testTarget(
            name: "CommenterPersistenceTests",
            dependencies: ["CommenterPersistence", "CommenterDomain"]
        ),
        .testTarget(
            name: "CommenterAppIntentsTests",
            dependencies: ["CommenterAppIntents"]
        )
    ]
)
