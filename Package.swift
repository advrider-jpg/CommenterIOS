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
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "CommenterTestSupport", targets: ["CommenterTestSupport"]),
        .executable(name: "CommenterIOSApp", targets: ["CommenterIOSApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", .upToNextMinor(from: "0.14.1")),
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
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .target(name: "DesignSystem"),
        .target(
            name: "AppFeature",
            dependencies: [
                "CommenterDomain",
                "CommentEngine",
                "CommenterPersistence",
                "CommenterImportExport",
                "DesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .target(
            name: "CommenterTestSupport",
            dependencies: ["CommenterDomain", "CommentEngine"]
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
            name: "AppFeatureTests",
            dependencies: [
                "AppFeature",
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
        )
    ]
)
