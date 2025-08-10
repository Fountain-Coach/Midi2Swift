import XCTest
import Foundation
@testable import UMP
@testable import Core

final class GoldenVectorTests: XCTestCase {
    struct UMPVector: Decodable {
        let caseName: String
        let message: String
        let container: String
        let raw: String
        let fields: [String: UInt64]
        enum CodingKeys: String, CodingKey { case caseName = "case", message, container, raw, fields }
    }

    func loadVectors() -> [UMPVector] {
        let fm = FileManager.default
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let spec = cwd.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("spec").appendingPathComponent("golden")
        guard let en = fm.enumerator(at: spec, includingPropertiesForKeys: nil) else { return [] }
        var out: [UMPVector] = []
        for case let url as URL in en {
            if url.pathExtension.lowercased() != "json" { continue }
            if let data = try? Data(contentsOf: url),
               let v = try? JSONDecoder().decode(UMPVector.self, from: data) {
                out.append(v)
            }
        }
        return out
    }

    func parseHex(_ s: String) -> (UInt32?, UInt64?) {
        let hex = s.hasPrefix("0x") ? String(s.dropFirst(2)) : s
        if hex.count == 8, let v = UInt32(hex, radix: 16) { return (v, nil) }
        if hex.count == 16, let v = UInt64(hex, radix: 16) { return (nil, v) }
        return (nil, nil)
    }

    func testGoldenVectors() {
        let strict = ProcessInfo.processInfo.environment["STRICT_FULL_SPEC"] == "1"
        let vectors = loadVectors()
        if strict && vectors.isEmpty {
            XCTFail("STRICT_FULL_SPEC: no golden vectors found.")
            return
        }
        for v in vectors {
            switch v.container {
            case "UMP32":
                guard let (w32, _) = parseHex(v.raw), let container = MessageRegistry.encode(name: v.message, fields: v.fields) else {
                    XCTFail("encode failed for \(v.message)"); continue
                }
                if case let .w32(out) = container {
                    XCTAssertEqual(out.raw, w32, "raw mismatch for \(v.caseName)")
                    guard let decoded = MessageRegistry.decode(name: v.message, container: .w32(out)) else {
                        XCTFail("decode failed for \(v.message)"); continue
                    }
                    XCTAssertEqual(decoded, v.fields, "roundtrip mismatch for \(v.caseName)")
                } else { XCTFail("unexpected container for UMP32") }
            case "UMP64":
                guard let (_, w64) = parseHex(v.raw), let w = w64, let container = MessageRegistry.encode(name: v.message, fields: v.fields) else {
                    XCTFail("encode failed for \(v.message)"); continue
                }
                if case let .w64(out) = container {
                    XCTAssertEqual(out.raw, w, "raw mismatch for \(v.caseName)")
                    guard let decoded = MessageRegistry.decode(name: v.message, container: .w64(out)) else {
                        XCTFail("decode failed for \(v.message)"); continue
                    }
                    XCTAssertEqual(decoded, v.fields, "roundtrip mismatch for \(v.caseName)")
                } else { XCTFail("unexpected container for UMP64") }
            default:
                if strict { XCTFail("STRICT_FULL_SPEC: unsupported container \(v.container)") }
            }
        }
    }
}
