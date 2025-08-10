import XCTest
@testable import MIDI_CI

final class CIFlowTests: XCTestCase {
    func testDiscoveryHappyPath() {
        let s0 = CIState()
        let (s1, eff1) = ciReduce(s0, .discoveryStart)
        XCTAssertEqual(s1.mode, .probeSent)
        XCTAssertTrue(eff1.contains { if case .sendSysEx(_) = $0 { return true } else { return false } })
        let (s2, eff2) = ciReduce(s1, .discoveryReply(remoteMUID: 0xAABBCCDD))
        XCTAssertEqual(s2.mode, .discovered)
        XCTAssertEqual(s2.remoteMUID, 0xAABBCCDD)
        XCTAssertEqual(eff2.count, 1)
        if case .none = eff2[0] {} else { XCTFail("expected .none") }
    }

    func testDiscoveryTimeout() {
        let s0 = CIState()
        let (s1, _) = ciReduce(s0, .discoveryStart)
        let (s2, eff2) = ciReduce(s1, .timeout)
        XCTAssertEqual(s2.mode, .failed)
        XCTAssertEqual(eff2.count, 1)
    }

    func testProtocolNegotiationHappy() {
        let s0 = CIState()
        let (s1, _) = ciReduce(s0, .protocolStart)
        XCTAssertEqual(s1.mode, .offerSent)
        let (s2, eff2) = ciReduce(s1, .protocolAccept)
        XCTAssertEqual(s2.mode, .negotiated)
        XCTAssertEqual(eff2.count, 1)
    }
}
