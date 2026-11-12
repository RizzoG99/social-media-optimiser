// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "SocialFrame",
    defaultLocalization: "it",
    platforms: [.macOS(.v14)],
    products: [.library(name: "SocialCore", targets: ["SocialCore"]), .executable(name: "SocialFrame", targets: ["SocialFrame"])],
    targets: [.target(name: "SocialCore", resources: [.process("Resources")]), .executableTarget(name: "SocialFrame", dependencies: ["SocialCore"], resources: [.process("Resources")]), .testTarget(name: "SocialCoreTests", dependencies: ["SocialCore"], resources: [.copy("Fixtures")]), .testTarget(name: "SocialFrameTests", dependencies: ["SocialFrame", "SocialCore"])],
    swiftLanguageModes: [.v5]
)
