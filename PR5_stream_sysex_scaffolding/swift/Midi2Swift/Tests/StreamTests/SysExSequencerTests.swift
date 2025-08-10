import XCTest
@testable import Stream

final class SysExSequencerTests: XCTestCase {
    func testCompleteFitsOnePacket() {
        let seq = SysExSequencer(mode: .sysex7(maxPayload: 8))
        let payload = Data([0,1,2,3,4])
        let pieces = seq.split(payload)
        XCTAssertEqual(pieces.count, 1)
        if case let .complete(d) = pieces[0] {
            XCTAssertEqual(d, payload)
        } else {
            XCTFail("expected complete")
        }
        XCTAssertEqual(seq.join(pieces), payload)
    }

    func testSplitJoinMultiplePackets() {
        let seq = SysExSequencer(mode: .sysex7(maxPayload: 4))
        let payload = Data([0,1,2,3,4,5,6,7,8,9])
        let pieces = seq.split(payload)
        XCTAssertEqual(pieces.count, 4) // 4 + 4 + 2
        XCTAssertNotNil(seq.join(pieces))
        XCTAssertEqual(seq.join(pieces), payload)
    }

    func testInvalidOrder() {
        let seq = SysExSequencer(mode: .sysex8(maxPayload: 4))
        let payload = Data([0,1,2,3,4,5,6])
        let pieces = seq.split(payload)
        // mutate: put end first -> invalid
        var bad = pieces
        if let last = bad.popLast() {
            bad.insert(last, at: 0)
        }
        XCTAssertNil(seq.join(bad))
    }
}
