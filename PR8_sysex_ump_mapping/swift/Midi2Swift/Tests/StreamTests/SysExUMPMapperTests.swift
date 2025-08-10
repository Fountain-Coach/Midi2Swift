import XCTest
@testable import Stream

final class SysExUMPMapperTests: XCTestCase {
    func testSysEx7RoundTrip() {
        let seq = SysExSequencer(mode: .sysex7(maxPayload: 5))
        let mapper = SysExUMPMapper(cfg: .init(mt: 0x3, group: 0x2, marker: (0x00,0x01,0x02,0x03)))
        let payload = Data(Array(0..<17))
        let pieces = seq.split(payload)
        // Wrap each piece to UMP32 and unwrap back
        var reassembled = Data()
        for p in pieces {
            let words = mapper.wrapSysEx7(p)
            guard let back = mapper.unwrapSysEx7(words) else { XCTFail("unwrap failed"); return }
            switch back {
            case .complete(let d), .start(let d), .continue(let d), .end(let d):
                reassembled.append(d)
            }
        }
        XCTAssertEqual(reassembled, payload)
    }

    func testSysEx8RoundTrip() {
        let seq = SysExSequencer(mode: .sysex8(maxPayload: 12))
        let mapper = SysExUMPMapper(cfg: .init(mt: 0x5, group: 0xA, marker: (0x10,0x11,0x12,0x13), streamID: 0x55))
        let payload = Data(Array(0..<40))
        let pieces = seq.split(payload)
        var reassembled = Data()
        for p in pieces {
            let words = mapper.wrapSysEx8(p)
            guard let back = mapper.unwrapSysEx8(words) else { XCTFail("unwrap8 failed"); return }
            switch back {
            case .complete(let d), .start(let d), .continue(let d), .end(let d):
                reassembled.append(d)
            }
        }
        XCTAssertEqual(reassembled, payload)
    }
}
