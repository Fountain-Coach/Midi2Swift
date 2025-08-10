import Foundation

struct Args {
    var matrix = "spec/matrix.json"
    var golden = "spec/golden"
    var sources = "swift/Midi2Swift/Sources"
}

@inline(__always) func arg(_ flag: String, _ argv: [String]) -> String? {
    guard let i = argv.firstIndex(of: flag), i+1 < argv.count else { return nil }
    return argv[i+1]
}

func parseArgs() -> Args {
    var a = Args()
    let argv = CommandLine.arguments
    if let v = arg("--matrix", argv) { a.matrix = v }
    if let v = arg("--golden", argv) { a.golden = v }
    if let v = arg("--sources", argv) { a.sources = v }
    return a
}

struct Matrix: Decodable { let messages: [Message] }
struct Message: Decodable {
    let name: String
    let family: String?
}

func loadMatrix(_ path: String) throws -> Matrix {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(Matrix.self, from: data)
}

func sanitizeType(_ name: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "_"))
    return String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
}

func findGeneratedFile(in sourcesRoot: URL) -> URL? {
    // default generated file location
    let candidate = sourcesRoot.appendingPathComponent("Core/Generated/Messages.swift")
    if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
    // fallback: search
    if let it = FileManager.default.enumerator(at: sourcesRoot, includingPropertiesForKeys: nil) {
        for case let u as URL in it { if u.lastPathComponent == "Messages.swift" { return u } }
    }
    return nil
}

func familyKey(_ s: String) -> String { s.lowercased().filter { $0.isLetter } }

func hasGolden(for family: String, under goldenRoot: URL) -> Bool {
    let key = familyKey(family)
    if let it = FileManager.default.enumerator(at: goldenRoot, includingPropertiesForKeys: nil) {
        for case let u as URL in it {
            guard u.pathExtension == "json" else { continue }
            let fnameKey = familyKey(u.deletingPathExtension().lastPathComponent)
            if fnameKey.contains(key) { return true }
        }
    }
    return false
}

@main struct ContractVerifier {
    static func main() throws {
        let args = parseArgs()
        let env = ProcessInfo.processInfo.environment
        let strictAreas = (env["STRICT_AREAS"] ?? "").split(separator: ",").map { String($0) }.filter { !$0.isEmpty }

        guard !strictAreas.isEmpty else {
            print("ContractVerifier: non-strict mode (no STRICT_AREAS). Nothing to verify.")
            return
        }

        let matrix = try loadMatrix(args.matrix)
        let sourcesURL = URL(fileURLWithPath: args.sources, isDirectory: true)
        let goldenURL = URL(fileURLWithPath: args.golden, isDirectory: true)
        guard let genFile = findGeneratedFile(in: sourcesURL) else {
            fputs("ContractVerifier: missing generated Messages.swift under \(args.sources)\n", stderr)
            exit(2)
        }
        let genText = try String(contentsOf: genFile)

        var failures: [String] = []
        for area in strictAreas {
            // filter messages by family or prefix in name
            let msgs = matrix.messages.filter { m in
                if let fam = m.family { return fam == area }
                return m.name.hasPrefix(area + ".") || m.name.hasPrefix(area + "_") || m.name == area
            }
            if msgs.isEmpty { failures.append("area=\(area): no messages in matrix"); continue }

            // golden presence
            if !hasGolden(for: area, under: goldenURL) {
                failures.append("area=\(area): no golden vectors found under \(args.golden)")
            }

            // generated types presence
            for m in msgs {
                let typeName = "Gen_" + sanitizeType(m.name)
                if !genText.contains("struct \(typeName)") {
                    failures.append("area=\(area): missing generated type \(typeName)")
                }
            }
        }

        if failures.isEmpty {
            print("ContractVerifier: strict checks passed for areas: \(strictAreas.joined(separator: ", "))")
        } else {
            fputs("ContractVerifier failures (\(failures.count)):\n- " + failures.joined(separator: "\n- ") + "\n", stderr)
            exit(1)
        }
    }
}
