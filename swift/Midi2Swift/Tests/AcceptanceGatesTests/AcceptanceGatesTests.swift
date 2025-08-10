import XCTest

final class AcceptanceGatesTests: XCTestCase {
    func testStrictFullSpecGate() throws {
        let strict = ProcessInfo.processInfo.environment["STRICT_FULL_SPEC"] == "1"
        if strict {
            XCTFail("STRICT_FULL_SPEC is enabled but the spec matrix and generated sources are not present yet.")
        }
    }
}
