import XCTest
import Foundation
import Sodium
@testable import Xoodyak

final class XoodyakTests: XCTestCase {
    let sodium = Sodium()
    
    func path(for filename: String) -> URL {
        return URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent(filename)
    }
    
    func testHash() {
        struct KAT: Decodable {
            let msg: String
            let md: String
        }
        
        let data = try! Data(contentsOf: path(for: "HashKAT.json"))
        let kats = try! JSONDecoder().decode([KAT].self, from: data)
        
        for kat in kats {
            let msgBytes = sodium.utils.hex2bin(kat.msg)!
            let mdBytes = sodium.utils.hex2bin(kat.md)!
            
            var xoodyak = Xoodyak()
            xoodyak.absorb(from: msgBytes)
            var newMD = Bytes()
            xoodyak.squeeze(count: mdBytes.count, to: &newMD)
            
            XCTAssertEqual(newMD, mdBytes)
        }
    }
    
    func testAEAD() {
        struct KAT: Decodable {
            let key: String
            let nonce: String
            let pt: String
            let ad: String
            let ct: String
        }
        
        let data = try! Data(contentsOf: path(for: "AEADKAT.json"))
        let kats = try! JSONDecoder().decode([KAT].self, from: data)
        
        for kat in kats {
            let keyBytes = sodium.utils.hex2bin(kat.key)!
            let nonceBytes = sodium.utils.hex2bin(kat.nonce)!
            let ptBytes = sodium.utils.hex2bin(kat.pt)!
            let adBytes = sodium.utils.hex2bin(kat.ad)!
            let ctBytes = sodium.utils.hex2bin(kat.ct)!
            
            var xoodyak = Xoodyak(key: keyBytes, id: [], counter: [])
            xoodyak.absorb(from: nonceBytes)
            xoodyak.absorb(from: adBytes)
            var newCT = Bytes()
            xoodyak.encrypt(from: ptBytes, to: &newCT)
            xoodyak.squeeze(count: 16, to: &newCT)

            XCTAssertEqual(newCT, ctBytes)
        }
    }
    
    func testMore() {
        // TODO: More tests
    }

    static var allTests = [
        ("testHash", testHash),
        ("testAEAD", testAEAD),
        ("testMore", testMore),
    ]
}
