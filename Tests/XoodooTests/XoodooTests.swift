import XCTest
@testable import Xoodoo

final class XoodooTests: XCTestCase {
    func testXoodoo() {
        var xoodoo = Xoodoo()
        
        for _ in 0..<384 {
            xoodoo.permute()
        }
        
        XCTAssertEqual(xoodoo.a.0, [0xfe04fab0, 0x42d5d8ce, 0x29c62ee7, 0x2a7ae5cf])
        XCTAssertEqual(xoodoo.a.1, [0xea36eba3, 0x14649e0a, 0xfe12521b, 0xfe2eff69])
        XCTAssertEqual(xoodoo.a.2, [0xf1826ca5, 0xfc4c41e0, 0x1597394f, 0xeb092faf])
    }
}
