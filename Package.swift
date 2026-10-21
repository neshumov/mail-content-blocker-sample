// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to
// build this package.

import PackageDescription

let package = Package(
    name: "MailBlocker",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        // The rules file shared between the app and the extension.
        .library(
            name: "MailBlockerShared",
            targets: ["MailBlockerShared"]
        ),
        // AdGuard rules to WebKit content-blocking JSON.
        .library(
            name: "MailBlockerCore",
            targets: ["MailBlockerCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/AdguardTeam/SafariConverterLib.git", exact: "4.3.0"),
    ],
    targets: [
        .target(
            name: "MailBlockerShared"
        ),
        .target(
            name: "MailBlockerCore",
            dependencies: [
                "MailBlockerShared",
                .product(name: "ContentBlockerConverter", package: "SafariConverterLib"),
            ]
        ),
        .testTarget(
            name: "MailBlockerSharedTests",
            dependencies: ["MailBlockerShared"]
        ),
        .testTarget(
            name: "MailBlockerCoreTests",
            dependencies: ["MailBlockerCore", "MailBlockerShared"]
        ),
    ]
)
