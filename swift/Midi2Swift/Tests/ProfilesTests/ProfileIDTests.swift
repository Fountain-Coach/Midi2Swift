import XCTest
@testable import Profiles

final class ProfileIDTests: XCTestCase {
    func testU32HexRoundTrip() {
        let pid = ProfileID.u32(0x1234ABCD)
        XCTAssertEqual(pid.description, "0x1234ABCD")
        XCTAssertEqual(ProfileID(hex: "0x1234ABCD"), pid)
        XCTAssertEqual(pid.toBytes(), [0x12,0x34,0xAB,0xCD])
    }

    func testUUIDRoundTrip() {
        let s = "00112233-4455-6677-8899-aabbccddeeff"
        guard let pid = ProfileID(hex: s) else { return XCTFail("parse failed") }
        XCTAssertEqual(pid.description, s.uppercased())
        let bytes = pid.toBytes()
        XCTAssertEqual(bytes.count, 16)
    }

    func testParseRejectsBad() {
        XCTAssertNil(ProfileID(hex: "nope"))
        XCTAssertNil(ProfileID(hex: "0xZZZZZZZZ"))
    }
}
