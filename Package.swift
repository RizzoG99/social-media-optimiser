// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "SocialFrame",
    platforms: [.macOS(.v14)],
    products: [.library(name: "SocialCore", targets: ["SocialCore"]), .executable(name: "SocialFrame", targets: ["SocialFrame"])],
    targets: [.target(name: "SocialCore"), .executableTarget(name: "SocialFrame", dependencies: ["SocialCore"]), .testTarget(name: "SocialCoreTests", dependencies: ["SocialCore"]), .testTarget(name: "SocialFrameTests", dependencies: ["SocialFrame", "SocialCore"])],
    swiftLanguageModes: [.v5]
)
