import XCTest
@testable import SelfControlCore

final class SelfControlTests: XCTestCase {
    func testVersionIsPresent() {
        XCTAssertFalse(SelfControlVersion.current.isEmpty)
    }
}
