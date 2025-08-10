import XCTest
@testable import MIDI_CI

final class CIDiscoveryTests: XCTestCase {
    func testDiscoveryHappyPath() {
        let s0 = CIState()
        let (s1, eff1) = ciReduce(s0, .startDiscovery)
        XCTAssertEqual(s1.mode, .probeSent)
        XCTAssertTrue(eff1.contains { if case .sendSysEx(_) = $0 { return true } else { return false } })
        let (s2, eff2) = ciReduce(s1, .discoveryReply(remoteMUID: 0x12345678))
        XCTAssertEqual(s2.mode, .discovered)
        XCTAssertEqual(s2.remoteMUID, 0x12345678)
        XCTAssertEqual(eff2.count, 1)
        if case .none = eff2[0] {} else { XCTFail("expected .none") }
    }

    func testDiscoveryTimeout() {
        let s0 = CIState()
        let (s1, _) = ciReduce(s0, .startDiscovery)
        let (s2, eff2) = ciReduce(s1, .timeout)
        XCTAssertEqual(s2.mode, .failed)
        XCTAssertEqual(eff2.count, 1)
    }
}
