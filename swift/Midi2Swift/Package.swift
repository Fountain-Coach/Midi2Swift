// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Midi2Swift",
    platforms: [
        .macOS(.v13), .iOS(.v16)
    ],
    products: [
        .library(name: "Midi2Swift", targets: ["Core","UMP","System","ChannelVoice","Stream","MIDI_CI","Profiles","PropertyExchange","ClipFile"])
    ],
    targets: [
        .target(name: "Core", path: "Sources/Core"),
        .target(name: "UMP", dependencies: ["Core"], path: "Sources/UMP"),
        .target(name: "System", dependencies: ["Core","UMP"], path: "Sources/System"),
        .target(name: "ChannelVoice", dependencies: ["Core","UMP"], path: "Sources/ChannelVoice"),
        .target(name: "Stream", dependencies: ["Core","UMP"], path: "Sources/Stream"),
        .target(name: "MIDI_CI", dependencies: ["Core","UMP"], path: "Sources/MIDI_CI"),
        .target(name: "Profiles", dependencies: ["Core","MIDI_CI"], path: "Sources/Profiles"),
        .target(name: "PropertyExchange", dependencies: ["Core","MIDI_CI"], path: "Sources/PropertyExchange"),
        .target(name: "ClipFile", dependencies: ["Core","UMP"], path: "Sources/ClipFile"),
        .testTarget(name: "AcceptanceGatesTests", dependencies: ["Core","UMP","System","ChannelVoice","Stream","MIDI_CI","Profiles","PropertyExchange","ClipFile"], path: "Tests/AcceptanceGatesTests"),
    ]
)
