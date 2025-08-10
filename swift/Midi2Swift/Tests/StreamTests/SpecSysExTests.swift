import XCTest
@testable import Stream

final class SpecSysExTests: XCTestCase {
    func testSysex7RoundTrip() {
        let p = Data([0x7E, 0x55, 0xAA])
        let words = sysex7Split(group: 0, payload: p)
        XCTAssertEqual(words.count, 2)
        let back = sysex7Join(words, expectGroup: 0)
        XCTAssertEqual(back, p)
    }
    func testSysex7Empty() {
        let words = sysex7Split(group: 3, payload: Data())
        XCTAssertEqual(words.count, 1)
        let back = sysex7Join(words, expectGroup: 3)
        XCTAssertEqual(back, Data())
    }
    func testSysex8RoundTrip() {
        let payload = Data(Array(0..<40))
        let chunks = sysex8Split(group: 15, streamID: 1, payload: payload)
        XCTAssertTrue(chunks.count >= 2)
        let back = sysex8Join(chunks, expectGroup: 15, expectStreamID: 1)
        XCTAssertEqual(back, payload)
    }
    func testSysex8SingleComplete() {
        let payload = Data([1,2,3,4,5])
        let chunks = sysex8Split(group: 2, streamID: 0x55, payload: payload)
        XCTAssertEqual(chunks.count, 1)
        let back = sysex8Join(chunks, expectGroup: 2, expectStreamID: 0x55)
        XCTAssertEqual(back, payload)
    }
}
