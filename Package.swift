// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ARCnet",
    platforms: [
        .iOS("18.0"), .macOS("13.0")
    ],
    products: [
        .library(name: "ARCnetCore", targets: ["ARCnetDomain", "ARCnetEngine", "ARCnetLLM", "ARCnetSecurity"])
    ],
    targets: [
        .target(name: "ARCnetDomain", path: "App/Domain"),
        .target(name: "ARCnetLLM", dependencies: [], path: "App/LLM"),
        .target(name: "ARCnetSecurity", dependencies: [], path: "App/Security"),
        .target(name: "ARCnetEngine", dependencies: ["ARCnetDomain", "ARCnetLLM"], path: "App/Engine"),
        .testTarget(name: "ARCnetCoreTests", dependencies: ["ARCnetDomain", "ARCnetEngine", "ARCnetLLM"], path: "Tests")
    ]
)

