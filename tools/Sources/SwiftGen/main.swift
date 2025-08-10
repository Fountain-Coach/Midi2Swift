import Foundation

struct Args {
    var matrixPath = "spec/matrix.json"
    var outDir = "swift/Midi2Swift/Sources"
}
func parseArgs() -> Args {
    var a = Args()
    var it = CommandLine.arguments.dropFirst().makeIterator()
    while let t = it.next() {
        switch t {
        case "--matrix": a.matrixPath = it.next() ?? a.matrixPath
        case "--out":    a.outDir     = it.next() ?? a.outDir
        default: break
        }
    }
    return a
}

enum GenError: Error, CustomStringConvertible {
    case readFail(String)
    case parseFail(String)
    case invalidMatrix(String)
    var description: String {
        switch self {
        case .readFail(let p):   return "SwiftGen: cannot read \(p)"
        case .parseFail(let p):  return "SwiftGen: cannot parse \(p) as JSON"
        case .invalidMatrix(let m): return "SwiftGen: invalid matrix.json — \(m)"
        }
    }
}

func loadMatrix(at path: String) throws -> [String: Any] {
    let url = URL(fileURLWithPath: path)
    guard let data = try? Data(contentsOf: url) else { throw GenError.readFail(path) }
    guard let any = try? JSONSerialization.jsonObject(with: data) else { throw GenError.parseFail(path) }
    guard let dict = any as? [String: Any] else { throw GenError.invalidMatrix("top-level must be object") }
    return dict
}

func validateMatrix(_ m: [String: Any]) throws {
    guard m["messages"] != nil else { throw GenError.invalidMatrix("missing 'messages' array") }
    // light validation only — generation is intentionally a no-op for now
}

let args = parseArgs()
do {
    let m = try loadMatrix(at: args.matrixPath)
    try validateMatrix(m)

    let out = URL(fileURLWithPath: args.outDir, isDirectory: true)
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

    // Write a tiny marker so step is observable but non-destructive.
    let marker = out.appendingPathComponent(".swiftgen-pass-through")
    let stamp = ISO8601DateFormatter().string(from: Date())
    try ("ok \(stamp)\n").data(using: .utf8)!.write(to: marker, options: .atomic)

    fputs("SwiftGen: pass-through (validated matrix, left sources intact) -> \(args.outDir)\n", stderr)
} catch {
    fputs("\(error)\n", stderr)
    exit(2)
}
