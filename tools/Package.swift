// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Midi2SwiftTools",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MatrixBuilder", targets: ["MatrixBuilder"]),
        .executable(name: "ContractVerifier", targets: ["ContractVerifier"]),
        .executable(name: "SwiftGen", targets: ["SwiftGen"])
    ],
    targets: [
        .executableTarget(name: "MatrixBuilder", path: "Sources/MatrixBuilder"),
        .executableTarget(name: "ContractVerifier", path: "Sources/ContractVerifier"),
        .executableTarget(name: "SwiftGen", path: "Sources/SwiftGen"),
    ]
)
