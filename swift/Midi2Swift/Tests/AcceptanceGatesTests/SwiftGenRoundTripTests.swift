import XCTest
@testable import Core

final class SwiftGenRoundTripTests: XCTestCase {
    func testCV1_NoteOn_roundTrip() {
        var m = Gen_CV1_NoteOn(mt: 2, group: 7, status: 0x90, data1: 64, data2: 100)
        let raw = m.raw
        let u = Gen_CV1_NoteOn(raw: raw)
        XCTAssertEqual(u.mt, 2)
        XCTAssertEqual(u.group, 7)
        XCTAssertEqual(u.status, 0x90)
        XCTAssertEqual(u.data1, 64)
        XCTAssertEqual(u.data2, 100)

        // mutate and re-check
        m.data2 = 127
        XCTAssertEqual(Gen_CV1_NoteOn(raw: m.raw).data2, 127)
    }

    func testCV1_ProgramChange_defaultsAndPack() {
        // defaults for reserved fields should be applied
        let m = Gen_CV1_ProgramChange(mt: 2, group: 1, status: 0xC0, program: 12)
        let u = Gen_CV1_ProgramChange(raw: m.raw)
        XCTAssertEqual(u.mt, 2)
        XCTAssertEqual(u.group, 1)
        XCTAssertEqual(u.status, 0xC0)
        XCTAssertEqual(u.program, 12)
        XCTAssertEqual(u.reserved0, 0)
    }

    func testCV2_NoteOn_roundTrip() {
        let m = Gen_ChannelVoice2_NoteOn(mt: 4, group: 3, statusNibble: 9, channel: 2, noteNumber: 60, attributeType: 0, velocity: 5000, attributeData: 0)
        let u = Gen_ChannelVoice2_NoteOn(raw: m.raw)
        XCTAssertEqual(u.group, 3)
        XCTAssertEqual(u.channel, 2)
        XCTAssertEqual(u.noteNumber, 60)
        XCTAssertEqual(u.velocity, 5000)
    }
}

