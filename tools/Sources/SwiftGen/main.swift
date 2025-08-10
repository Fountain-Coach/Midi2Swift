import Foundation

@main struct SwiftGen {
    static func main() throws {
        let args = CommandLine.arguments.dropFirst()
        if args.contains("--help") || args.contains("-h") || args.isEmpty {
            print("SwiftGen — generate Swift sources from spec/matrix.json (placeholder).")
            print("Usage: SwiftGen --in spec/matrix.json --out swift/Midi2Swift/Sources")
            return
        }
        fputs("SwiftGen: generator not yet implemented.\n", stderr)
        exit(2)
    }
}
