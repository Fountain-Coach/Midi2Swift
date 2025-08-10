import XCTest
import Foundation

final class GoldenVectorsSmokeTests: XCTestCase {
    private func repoRoot(from file: StaticString = #filePath) -> URL {
        var u = URL(fileURLWithPath: "\(file)")
        u.deleteLastPathComponent() // dir of this file
        for _ in 0..<10 {
            let candidate = u.appendingPathComponent("spec/golden/system_common_vectors.json")
            if FileManager.default.fileExists(atPath: candidate.path) { return u }
            u.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    func testParseSystemCommonGolden() throws {
        let root = repoRoot()
        let golden = root.appendingPathComponent("spec/golden/system_common_vectors.json")

        let data = try Data(contentsOf: golden)
        XCTAssertGreaterThan(data.count, 0, "golden file is empty")

        let json = try JSONSerialization.jsonObject(with: data)
        guard let arr = json as? [Any], !arr.isEmpty else {
            XCTFail("expected non-empty array"); return
        }

        var checked = 0
        for case let obj as [String: Any] in arr {
            if let raw = obj["raw"] as? String {
                XCTAssertTrue(raw.lowercased().hasPrefix("0x"), "raw missing 0x")
                let hex = raw.dropFirst(2)
                XCTAssertGreaterThanOrEqual(hex.count, 8, "raw too short")
                XCTAssertTrue(hex.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) || ("A"..."F").contains($0) },
                              "raw contains non-hex characters")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 0, "no entries with 'raw' hex found")
    }
}
