// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ARCnet",
    platforms: [
        .iOS("18.0"), .macOS("13.0")
    ],
    products: [
        .library(name: "ARCnetCore", targets: ["ARCnetDomain", "ARCnetEngine", "ARCnetLLM", "ARCnetSecurity", "ARCnetData", "ARCnetAgents"])
    ],
    targets: [
        // Domain layer - core models
        .target(name: "ARCnetDomain", path: "App/Domain"),

        // LLM layer - OpenAI and embedding clients
        .target(name: "ARCnetLLM", dependencies: [], path: "App/LLM"),

        // Security layer - keychain and encryption
        .target(name: "ARCnetSecurity", dependencies: [], path: "App/Security"),

        // Data layer - repositories, importers, gateways
        .target(
            name: "ARCnetData",
            dependencies: ["ARCnetDomain"],
            path: "App/Data"
        ),

        // Agents layer - agent protocol and implementations
        .target(
            name: "ARCnetAgents",
            dependencies: ["ARCnetDomain", "ARCnetLLM", "ARCnetData"],
            path: "App/Agents"
        ),

        // Engine layer - orchestration and selection
        .target(
            name: "ARCnetEngine",
            dependencies: ["ARCnetDomain", "ARCnetLLM", "ARCnetData", "ARCnetAgents"],
            path: "App/Engine"
        ),

        // Tests
        .testTarget(
            name: "ARCnetCoreTests",
            dependencies: ["ARCnetDomain", "ARCnetEngine", "ARCnetLLM", "ARCnetData", "ARCnetAgents"],
            path: "Tests"
        )
    ]
)
