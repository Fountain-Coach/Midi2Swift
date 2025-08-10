import Foundation

struct Args {
    var input = "spec"
    var output = "spec/matrix.json"
}
func parseArgs() -> Args {
    var a = Args()
    var it = CommandLine.arguments.dropFirst().makeIterator()
    while let t = it.next() {
        switch t {
        case "--in":  a.input  = it.next() ?? a.input
        case "--out": a.output = it.next() ?? a.output
        default: break
        }
    }
    return a
}

func readJSON(at url: URL) -> Any? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONSerialization.jsonObject(with: data, options: [])
}

func writeJSON(_ obj: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
}

let args = parseArgs()
let specRoot = URL(fileURLWithPath: args.input, isDirectory: true)
let seedsRoot = specRoot.appendingPathComponent("seeds", isDirectory: true)
let fm = FileManager.default

var messages: [[String: Any]] = []
var ciFlows: [[String: Any]] = []
var profilesMerged: [String: Any] = [:]
var peMerged: [String: Any] = [:]

// Walk seeds/**.json
let enumerator = fm.enumerator(at: seedsRoot, includingPropertiesForKeys: nil)!
for case let url as URL in enumerator {
    guard url.pathExtension == "json" else { continue }
    guard let obj = readJSON(at: url) else { continue }
    guard let dict = obj as? [String: Any] else { continue }

    // Messages
    if let items = dict["items"] as? [[String: Any]] {
        messages.append(contentsOf: items)
        continue
    }
    // CI flows
    if url.path.contains("/ci/"), let flows = dict["flows"] as? [[String: Any]] {
        ciFlows.append(contentsOf: flows)
        continue
    }
    // Profiles
    if url.path.contains("/profiles/") {
        for (k,v) in dict { profilesMerged[k] = v } // shallow merge
        continue
    }
    // Property Exchange
    if url.path.contains("/property_exchange/") {
        for (k,v) in dict { peMerged[k] = v } // shallow merge
        continue
    }
}

// Stable sort messages by name if present
messages.sort { (a, b) -> Bool in
    let na = (a["name"] as? String) ?? ""
    let nb = (b["name"] as? String) ?? ""
    return na < nb
}

// Build matrix
var matrix: [String: Any] = [
    "meta": [
        "generated_at": ISO8601DateFormatter().string(from: Date()),
        "source": "seeds-only"
    ],
    "messages": messages
]
if !ciFlows.isEmpty { matrix["ci"] = ["flows": ciFlows] }
if !profilesMerged.isEmpty { matrix["profiles"] = profilesMerged }
if !peMerged.isEmpty { matrix["property_exchange"] = peMerged }

// Write
try writeJSON(matrix, to: URL(fileURLWithPath: args.output))
fputs("MatrixBuilder: seeds-only matrix written to \(args.output)\n", stderr)
