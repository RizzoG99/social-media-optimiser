// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "SocialFrame",
    platforms: [.macOS(.v14)],
    products: [.library(name: "SocialCore", targets: ["SocialCore"])],
    targets: [.target(name: "SocialCore"), .testTarget(name: "SocialCoreTests", dependencies: ["SocialCore"])],
    swiftLanguageModes: [.v5]
)
