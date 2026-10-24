// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TicketLibre",
    platforms: [.iOS(.v18)],
    products: [.library(name: "TicketLibre", targets: ["TicketLibre"])],
    targets: [
        .target(
            name: "TicketLibre",
            path: "TicketLibre",
            exclude: ["Assets.xcassets", "Info.plist", "PrivacyInfo.xcprivacy"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
