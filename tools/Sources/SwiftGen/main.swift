import Foundation

// --- CLI ---
@inline(__always) func arg(_ flag: String, _ argv: [String]) -> String? {
    guard let i = argv.firstIndex(of: flag), i+1 < argv.count else { return nil }
    return argv[i+1]
}
let argv = CommandLine.arguments
guard let matrixPath = arg("--matrix", argv), let outDir = arg("--out", argv) else {
    fputs("usage: SwiftGen --matrix <matrix.json> --out <SourcesDir>\n", stderr)
    exit(2)
}

// --- Matrix model (liberal decoding) ---
struct Matrix: Decodable { let messages: [Message] }

struct Message: Decodable {
    let name: String
    let container: String          // "UMP32" | "UMP64" (inferred if missing)
    let fields: [Field]
    let defaults: [String: UInt64]?

    enum CodingKeys: String, CodingKey { case name, container, containerBits, fields, defaults }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        name     = try c.decode(String.self, forKey: .name)
        fields   = try c.decode([Field].self, forKey: .fields)
        defaults = try c.decodeIfPresent([String: UInt64].self, forKey: .defaults)
        if let explicit = try c.decodeIfPresent(String.self, forKey: .container) {
            container = explicit
        } else if let bits = try c.decodeIfPresent(Int.self, forKey: .containerBits) {
            container = (bits <= 32) ? "UMP32" : "UMP64"
        } else {
            let maxBit = fields.map { $0.bitOffset + $0.bitWidth }.max() ?? 0
            container = (maxBit <= 32) ? "UMP32" : "UMP64"
        }
    }
}

struct Field: Decodable {
    let name: String
    let bitOffset: Int
    let bitWidth: Int
    let range: [UInt64]?
    let enumRef: String?

    enum CodingKeys: String, CodingKey {
        case name, bitOffset, bitWidth, range
        case enumRef = "enum"
        // aliases
        case offset, width
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        bitOffset = try c.decodeIfPresent(Int.self, forKey: .bitOffset)
                  ?? c.decode(Int.self, forKey: .offset)
        bitWidth  = try c.decodeIfPresent(Int.self, forKey: .bitWidth)
                  ?? c.decode(Int.self, forKey: .width)
        range     = try c.decodeIfPresent([UInt64].self, forKey: .range)
        enumRef   = try c.decodeIfPresent(String.self, forKey: .enumRef)
    }
}

// --- Load matrix ---
let matrixURL = URL(fileURLWithPath: matrixPath)
let data = try Data(contentsOf: matrixURL)
let matrix = try JSONDecoder().decode(Matrix.self, from: data)

// --- Output dir ---
let genDir = URL(fileURLWithPath: outDir).appendingPathComponent("Generated", isDirectory: true)
try FileManager.default.createDirectory(at: genDir, withIntermediateDirectories: true)

// --- Helpers emitted into the file ---
func header(_ note: String) -> String {
    let ts = ISO8601DateFormatter().string(from: Date())
    return """
    // AUTO-GENERATED — do not edit.
    // \(note)
    // Written by SwiftGen at \(ts)

    """
}
let helpers = """
@inline(__always) func _shift(_ N:Int,_ o:Int,_ w:Int) -> UInt64 { UInt64(N - o - w) }
@inline(__always) func _mask(_ w:Int) -> UInt64 { (w == 64) ? ~UInt64(0) : ((UInt64(1)<<w) - 1) }
@inline(__always) func _set(_ C:UInt64,_ v:UInt64,_ o:Int,_ w:Int,_ N:Int) -> UInt64 {
    let s = _shift(N,o,w); let m = _mask(w) << s
    return (C & ~m) | ((v & _mask(w)) << s)
}
@inline(__always) func _get(_ C:UInt64,_ o:Int,_ w:Int,_ N:Int) -> UInt64 {
    let s = _shift(N,o,w); return (C >> s) & _mask(w)
}
"""

func sanitize(_ name: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "_"))
    return String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
}

func intType(for bits: Int) -> String {
    if bits <= 8 { return "UInt8" }
    if bits <= 16 { return "UInt16" }
    if bits <= 32 { return "UInt32" }
    return "UInt64"
}

// --- Codegen ---
var out = header("Typed message structs from matrix (\(data.count) bytes)") + helpers + "\n"

for msg in matrix.messages {
    let N = (msg.container.uppercased() == "UMP64") ? 64 : 32
    let typeName = "Gen_" + sanitize(msg.name)

    out += """
    /// AUTO: \(msg.name) in \(msg.container)
    public struct \(typeName) {
        public var raw: UInt64
        /// Create from raw container value.
        public init(raw: UInt64) { self.raw = raw }

    """

    for f in msg.fields {
        let fname = sanitize(f.name)
        let ftype = intType(for: f.bitWidth)
        let hi = f.bitOffset + f.bitWidth - 1
        let rangeDoc: String
        if let r = f.range, r.count == 2 { rangeDoc = " range [\(r[0])..\(r[1])]" } else { rangeDoc = "" }
        out += """
        /// bits [\(f.bitOffset)..\(hi)], width \(f.bitWidth).\(rangeDoc)
        public var \(fname): \(ftype) {
            get { \(ftype)(_get(raw, \(f.bitOffset), \(f.bitWidth), \(N))) }
            set { raw = _set(raw, UInt64(newValue), \(f.bitOffset), \(f.bitWidth), \(N)) }
        }

        """
    }

    if !msg.fields.isEmpty {
        let params = msg.fields.map { f in
            let name = sanitize(f.name)
            let t = intType(for: f.bitWidth)
            if let d = msg.defaults?[f.name] {
                return "\(name): \(t) = \(t)(\(d))"
            } else {
                return "\(name): \(t)"
            }
        }.joined(separator: ", ")
        out += "public init(\(params)) { self.raw = 0\n"
        for f in msg.fields { out += "    self.\(sanitize(f.name)) = \(sanitize(f.name))\n" }
        out += "}\n"
    }

    out += "}\n\n"
}

let fileURL = genDir.appendingPathComponent("Messages.swift")
try out.write(to: fileURL, atomically: true, encoding: .utf8)
print("SwiftGen: generated \(fileURL.path) with \(matrix.messages.count) messages.")
