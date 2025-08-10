import Foundation

struct CLI {
    var matrixPath: String = "spec/matrix.json"
    var goldenDir: String = "spec/golden"
    var sourcesDir: String = "../swift/Midi2Swift/Sources"
    static func parse() -> CLI {
        var cli = CLI()
        var it = CommandLine.arguments.dropFirst().makeIterator()
        while let arg = it.next() {
            switch arg {
            case "--matrix":
                if let v = it.next() { cli.matrixPath = v }
            case "--golden":
                if let v = it.next() { cli.goldenDir = v }
            case "--sources":
                if let v = it.next() { cli.sourcesDir = v }
            case "--help", "-h":
                print("ContractVerifier — enforce full-spec gates")
                print("Usage: ContractVerifier --matrix spec/matrix.json --golden spec/golden --sources ../swift/Midi2Swift/Sources")
                exit(0)
            default:
                fputs("Unknown argument: \(arg)\n", stderr)
                exit(2)
            }
        }
        return cli
    }
}

enum CVError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case invalidJSON(String)
    case structural(String)
    case coverage(String)
    case generated(String)
    var description: String {
        switch self {
        case .fileNotFound(let s): return "file not found: " + s
        case .invalidJSON(let s):  return "invalid json: " + s
        case .structural(let s):   return "structural violation: " + s
        case .coverage(let s):     return "coverage violation: " + s
        case .generated(let s):    return "generated code violation: " + s
        }
    }
}

struct Field { let name: String; let off: Int; let width: Int; let reserved: Bool }
struct Message { let family: String; let name: String; let bits: Int; let fields: [Field]; let defaults: [String:Int]? }

func loadMatrix(_ path: String) throws -> [Message] {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else { throw CVError.fileNotFound(path) }
    let data = try Data(contentsOf: url)
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw CVError.invalidJSON("matrix root is not object")
    }
    guard let arr = root["messages"] as? [Any] else { return [] }
    var out: [Message] = []
    for item in arr {
        guard let m = item as? [String: Any] else { continue }
        guard let family = m["family"] as? String,
              let name = m["name"] as? String,
              let bits = m["containerBits"] as? Int,
              let flds = m["fields"] as? [[String: Any]] else {
            throw CVError.structural("message missing required keys: \(item)")
        }
        var fields: [Field] = []
        for fd in flds {
            guard let n = fd["name"] as? String,
                  let o = fd["bitOffset"] as? Int,
                  let w = fd["bitWidth"] as? Int else {
                throw CVError.structural("field missing required keys in \(name)")
            }
            let r = (fd["reserved"] as? Bool) ?? false
            fields.append(Field(name: n, off: o, width: w, reserved: r))
        }
        let defaults = m["defaults"] as? [String:Int]
        out.append(Message(family: family, name: name, bits: bits, fields: fields, defaults: defaults))
    }
    return out
}

func checkStructure(_ msgs: [Message]) throws {
    for m in msgs {
        // widths sum
        let sum = m.fields.reduce(0) { $0 + $1.width }
        if sum != m.bits {
            throw CVError.structural("bit width sum != container for \(m.name): sum=\(sum) vs \(m.bits)")
        }
        // non-overlap and range
        var used = Set<Int>()
        for f in m.fields {
            if f.off < 0 || f.width <= 0 || f.off + f.width > m.bits {
                throw CVError.structural("field out of bounds in \(m.name): \(f.name) offset=\(f.off) width=\(f.width)")
            }
            for b in f.off..<(f.off + f.width) {
                if used.contains(b) {
                    throw CVError.structural("overlap in \(m.name) at bit \(b) for field \(f.name)")
                }
                used.insert(b)
            }
        }
        // reserved defaults == 0
        let defaults = m.defaults ?? [:]
        for f in m.fields where f.reserved {
            if defaults[f.name] != 0 {
                throw CVError.structural("reserved field \(f.name) in \(m.name) must default to 0")
            }
        }
    }
}

func loadGoldenMessages(_ dir: String) -> Set<String> {
    var names = Set<String>()
    guard let en = FileManager.default.enumerator(atPath: dir) else { return names }
    for case let p as String in en {
        if p.hasSuffix(".json") {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: (dir as NSString).appendingPathComponent(p))),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                for item in arr {
                    if let v = item as? [String: Any], let name = v["message"] as? String {
                        names.insert(name)
                    }
                }
            }
        }
    }
    return names
}

func checkCoverage(_ msgs: [Message], goldenDir: String, strict: Bool) throws {
    let goldenNames = loadGoldenMessages(goldenDir)
    if strict {
        var missing: [String] = []
        for m in msgs {
            if !goldenNames.contains(m.name) {
                missing.append(m.name)
            }
        }
        if !missing.isEmpty {
            throw CVError.coverage("missing golden vectors for messages: " + missing.sorted().joined(separator: ", "))
        }
    } else {
        if goldenNames.isEmpty {
            fputs("WARN: no golden vectors found (non-strict mode)\n", stderr)
        }
    }
}

func checkGeneratedSources(_ msgs: [Message], sourcesDir: String, strict: Bool) throws {
    // Ensure generated type files exist for each message.
    // Expected path: UMP/Generated/Messages/<Family>/<Name_with_dot_replaced>.swift
    var missing: [String] = []
    for m in msgs {
        let typeName = m.name.replacingOccurrences(of: ".", with: "_")
        let rel = "UMP/Generated/Messages/\(m.family)/\(typeName).swift"
        let p = (sourcesDir as NSString).appendingPathComponent(rel)
        if !FileManager.default.fileExists(atPath: p) {
            missing.append(rel)
        }
    }
    if strict && !missing.isEmpty {
        throw CVError.generated("missing generated source files: " + missing.joined(separator: ", "))
    }
    // Ensure generated sources have no TODO/TBD/unimplemented
    let genRoot = (sourcesDir as NSString).appendingPathComponent("UMP/Generated")
    if let en = FileManager.default.enumerator(atPath: genRoot) {
        for case let p as String in en {
            if p.hasSuffix(".swift") {
                let full = (genRoot as NSString).appendingPathComponent(p)
                if let s = try? String(contentsOfFile: full, encoding: .utf8) {
                    if s.contains("TODO") || s.contains("TBD") || s.contains("unimplemented") {
                        throw CVError.generated("found placeholder markers in generated source: \(p)")
                    }
                }
            }
        }
    }
}

let cli = CLI.parse()
let strict = (ProcessInfo.processInfo.environment["STRICT_FULL_SPEC"] ?? "0") == "1"

do {
    let messages = try loadMatrix(cli.matrixPath)
    try checkStructure(messages)
    try checkCoverage(messages, goldenDir: cli.goldenDir, strict: strict)
    try checkGeneratedSources(messages, sourcesDir: cli.sourcesDir, strict: strict)
    print("ContractVerifier: OK (messages=\(messages.count)) strict=\(strict)")
} catch {
    fputs("ContractVerifier FAILED: \(error)\n", stderr)
    exit(2)
}
