\
import Foundation

struct CLI {
    var outPath: String = "spec/matrix.json"
    var sourcesChecksumsPath: String = "spec/sources/checksums.json"
    var pretty: Bool = true
    static func parse() -> CLI {
        var cli = CLI()
        var it = CommandLine.arguments.dropFirst().makeIterator()
        while let arg = it.next() {
            switch arg {
            case "--out":
                if let v = it.next() { cli.outPath = v }
            case "--sources":
                if let v = it.next() { cli.sourcesChecksumsPath = v }
            case "--compact":
                cli.pretty = false
            case "--help", "-h":
                print("MatrixBuilder — build spec/matrix.json from authoritative PDFs")
                print("Usage: MatrixBuilder [--out spec/matrix.json] [--sources spec/sources/checksums.json] [--compact]")
                exit(0)
            default:
                fputs("Unknown argument: \\(arg)\\n", stderr)
                exit(2)
            }
        }
        return cli
    }
}

func loadJSONFile<T: Decodable>(_ path: String, as: T.Type) throws -> T {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(T.self, from: data)
}

struct Checksums: Decodable {
    let mapping: [String:String]
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let m = try c.decode([String:String].self)
        self.mapping = m
    }
}

struct Matrix: Encodable {
    struct Meta: Encodable {
        let generated_at: String
        let schema_version: String
        let pdf_sha256: [String:String]
    }
    let meta: Meta
    let catalog: [String: AnyEncodable]
    let enums: [String:AnyEncodable]
    let messages: [AnyEncodable]
    struct Transactions: Encodable {
        let midi_ci: [AnyEncodable]
        let profiles: [AnyEncodable]
        let property_exchange: [AnyEncodable]
    }
    let transactions: Transactions
    struct Clip: Encodable {
        let header: AnyEncodable?
        let chunks: [AnyEncodable]
        let invariants: [String]
    }
    let clip_file: Clip
    struct Coverage: Encodable {
        struct Section: Encodable { let status: String; let completeness: Int; let notes: [String] }
        let summary: String
        let sections: [String:Section]
    }
    let coverage: Coverage
}

/// Helper to encode heterogenous values
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) { _encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

let cli = CLI.parse()

// Load checksums (authoritative provenance for PDFs)
var pdfSha: [String:String] = [:]
do {
    let checksums: Checksums = try loadJSONFile(cli.sourcesChecksumsPath, as: Checksums.self)
    pdfSha = checksums.mapping
} catch {
    fputs("MatrixBuilder error: cannot read checksums at \\(cli.sourcesChecksumsPath): \\(error)\\n", stderr)
    exit(2)
}

// Build skeleton matrix (deterministic ordering)
let generatedAt = ISO8601DateFormatter().string(from: Date())
let sortedSha = pdfSha.sorted(by: { $0.key < $1.key })
let pdfShaOrdered = Dictionary(uniqueKeysWithValues: sortedSha)

let meta = Matrix.Meta(generated_at: generatedAt, schema_version: "1.0.0", pdf_sha256: pdfShaOrdered)

let families = ["Utility","System","ChannelVoice1","ChannelVoice2","Data","Stream","SysEx7","SysEx8"]
let notes = [
    "Seeded matrix from authoritative PDFs; content will be filled by clause-parsers in subsequent PRs.",
    "Deterministic ordering: filenames ascending; enums/messages initially empty."
]

let coverage = Matrix.Coverage(
    summary: "Seeded. No content parsed yet.",
    sections: [
        "ump": .init(status: "seeded", completeness: 0, notes: notes),
        "midi_ci": .init(status: "seeded", completeness: 0, notes: notes),
        "profiles": .init(status: "seeded", completeness: 0, notes: notes),
        "property_exchange": .init(status: "seeded", completeness: 0, notes: notes),
        "clip_file": .init(status: "seeded", completeness: 0, notes: notes),
    ]
)

#warning("MatrixBuilder: merging catalog seeds if present (non-fatal).")
// Merge catalog seed: spec/catalog/ump.json -> matrix.catalog.ump
var catalog: [String: AnyEncodable] = [:]
do {
    let catalogPath = "spec/catalog/ump.json"
    if FileManager.default.fileExists(atPath: catalogPath) {
        let data = try Data(contentsOf: URL(fileURLWithPath: catalogPath))
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        catalog["ump"] = AnyEncodable(obj)
    }
} catch {
    fputs("MatrixBuilder warning: could not read catalog seed: \(error)\n", stderr)
}

// Merge message seeds: spec/seeds/messages/*.json -> matrix.messages
var seededMessages: [[String: Any]] = []
do {
    let seedsDir = "spec/seeds/messages"
    if let items = try? FileManager.default.contentsOfDirectory(atPath: seedsDir) {
        for file in items where file.hasSuffix(".json") {
            let p = (seedsDir as NSString).appendingPathComponent(file)
            if let data = try? Data(contentsOf: URL(fileURLWithPath: p)),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = obj["items"] as? [[String: Any]] {
                seededMessages.append(contentsOf: arr)
            }
        }
    }
}
// Attach to matrix messages
// Note: actual clause-parsed messages will be appended later; here we seed a subset (System RT)

let matrix = Matrix(


    meta: meta,
    catalog: catalog,
    enums: [:],
    messages: [],
    transactions: .init(midi_ci: [], profiles: [], property_exchange: []),
    clip_file: .init(header: nil, chunks: [], invariants: []),
    coverage: coverage
)

// Encode to JSON
let encoder = JSONEncoder()
encoder.outputFormatting = cli.pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
do {
    let data = try encoder.encode(matrix)
    let url = URL(fileURLWithPath: cli.outPath)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
    print("MatrixBuilder: wrote \\(cli.outPath) with \\(pdfShaOrdered.count) PDF provenance entries.")
} catch {
    fputs("MatrixBuilder error: \\(error)\\n", stderr)
    exit(2)
}
