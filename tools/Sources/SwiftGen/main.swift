import Foundation

@inline(__always) func arg(_ flag: String, _ argv: [String]) -> String? {
    guard let i = argv.firstIndex(of: flag), i+1 < argv.count else { return nil }
    return argv[i+1]
}

let argv = CommandLine.arguments
guard let matrix = arg("--matrix", argv), let out = arg("--out", argv) else {
    fputs("usage: SwiftGen --matrix <matrix.json> --out <SourcesDir>\n", stderr)
    exit(2)
}

let url = URL(fileURLWithPath: matrix)
let size = (try? Data(contentsOf: url).count) ?? 0
print("SwiftGen: scanned matrix (\(size) bytes); pass-through (leaves sources intact) -> \(out)")
