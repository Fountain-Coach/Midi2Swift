import XCTest
@testable import PropertyExchange

final class PEHeaderTests: XCTestCase {
    func testStatusCategories() {
        XCTAssertTrue(PEStatus.code(200).isSuccess)
        XCTAssertTrue(PEStatus.code(204).isSuccess)
        XCTAssertTrue(PEStatus.code(404).isClientError)
        XCTAssertTrue(PEStatus.code(500).isServerError)
        XCTAssertFalse(PEStatus.code(199).isSuccess)
    }

    func testRequestReplyRoundTrip() {
        let req = PERequestHeader(resource: "identity", version: "1.0", contentType: "application/json")
        let rep = PEReplyHeader(status: .code(201), reason: "created", version: "1.0")
        XCTAssertEqual(req.resource, "identity")
        XCTAssertEqual(rep.status.codeValue, 201)
        XCTAssertEqual(rep.reason, "created")
        XCTAssertTrue(rep.status.isSuccess)
    }
}
