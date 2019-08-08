import XCTest
@testable import Xoodoo

final class XoodooTests: XCTestCase {
    func testXoodoo() {
        var xoodoo = Xoodoo()
        
        for _ in 0..<384 {
            xoodoo.permute()
        }
        
        let expected = (
            SIMD4<UInt32>(0xfe04fab0, 0x42d5d8ce, 0x29c62ee7, 0x2a7ae5cf),
            SIMD4<UInt32>(0xea36eba3, 0x14649e0a, 0xfe12521b, 0xfe2eff69),
            SIMD4<UInt32>(0xf1826ca5, 0xfc4c41e0, 0x1597394f, 0xeb092faf)
        )
        
        XCTAssertEqual(xoodoo.a.0, expected.0)
        XCTAssertEqual(xoodoo.a.1, expected.1)
        XCTAssertEqual(xoodoo.a.2, expected.2)
    }
    
    static var allTests = [
        ("testXoodoo", testXoodoo),
    ]
}
