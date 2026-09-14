import XCTest
@testable import PlainPad
final class PlainPadTests: XCTestCase {
    func testCoreBehavior() throws {
        for (name, test) in coreTests {
            do { try test() } catch { XCTFail("\(name): \(error)") }
        }
    }
}
