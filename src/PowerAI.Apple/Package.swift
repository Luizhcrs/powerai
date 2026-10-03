// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "PowerAIApple",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "powerai-apple", targets: ["PowerAIApple"])
    ],
    targets: [
        .executableTarget(
            name: "PowerAIApple"
        ),
    ]
)
