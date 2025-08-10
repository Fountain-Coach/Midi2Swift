import XCTest
import Foundation

final class GoldenVectorsSmokeTests: XCTestCase {
    func testParseSystemCommonGolden() throws {
        // repo root = ../../../../ from this file
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()  // AcceptanceGatesTests
            .deletingLastPathComponent()             // Tests
            .deletingLastPathComponent()             // Midi2Swift
            .deletingLastPathComponent()             // swift
        let golden = root.appendingPathComponent("spec/golden/system_common_vectors.json")

        let data = try Data(contentsOf: golden)
        XCTAssertGreaterThan(data.count, 0, "golden file is empty")

        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let arr = json as? [Any] else {
            XCTFail("expected top-level array"); return
        }
        XCTAssertFalse(arr.isEmpty, "no vectors in system_common_vectors.json")

        var checked = 0
        for case let obj as [String: Any] in arr {
            if let raw = obj["raw"] as? String {
                // simple hex format check: 0x + A-F0-9 (upper/lower), length >= 8
                XCTAssertTrue(raw.hasPrefix("0x") || raw.hasPrefix("0X"), "raw missing 0x prefix")
                let hex = raw.dropFirst(2)
                XCTAssertGreaterThanOrEqual(hex.count, 8, "raw too short")
                XCTAssertTrue(hex.allSatisfy({ ("0"..."9").contains($0) || ("a"..."f").contains($0) || ("A"..."F").contains($0) }),
                              "raw contains non-hex characters")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 0, "no entries with 'raw' hex found")
    }
}
