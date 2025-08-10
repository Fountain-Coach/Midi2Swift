import Foundation

@inline(__always) func arg(_ flag: String, _ argv: [String]) -> String? {
    guard let i = argv.firstIndex(of: flag), i+1 < argv.count else { return nil }
    return argv[i+1]
}

let argv = CommandLine.arguments
guard let matrixPath = arg("--matrix", argv), let outDir = arg("--out", argv) else {
    fputs("usage: SwiftGen --matrix <matrix.json> --out <SourcesDir>\n", stderr)
    exit(2)
}

// read matrix just to prove IO and size
let matrixURL = URL(fileURLWithPath: matrixPath)
let matrixBytes = (try? Data(contentsOf: matrixURL).count) ?? 0

// ensure Generated dir
let genDir = URL(fileURLWithPath: outDir).appendingPathComponent("Generated", isDirectory: true)
try? FileManager.default.createDirectory(at: genDir, withIntermediateDirectories: true)

// write a tiny, always-compilable file
let ts = ISO8601DateFormatter().string(from: Date())
let code = """
// AUTO-GENERATED — do not edit.
// Written by SwiftGen at \(ts)
// Matrix bytes: \(matrixBytes)

public enum CodegenInfo {
    public static let generatedAt: String = "\(ts)"
    public static let matrixByteCount: Int = \(matrixBytes)
}
"""

let outFile = genDir.appendingPathComponent("CodegenInfo.swift")
try code.write(to: outFile, atomically: true, encoding: .utf8)

print("SwiftGen: generated \(outFile.path) (matrix \(matrixBytes) bytes)")
