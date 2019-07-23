import XCTest
import Foundation
@testable import Xoodyak

final class XoodyakTests: XCTestCase {
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
            let msgBytes = kat.msg.hexToBytes()
            let mdBytes = kat.md.hexToBytes()
            
            var xoodyak = Xoodyak()
            xoodyak.absorb(from: msgBytes)
            var newMD = [UInt8]()
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
            let keyBytes = kat.key.hexToBytes()
            let nonceBytes = kat.nonce.hexToBytes()
            let ptBytes = kat.pt.hexToBytes()
            let adBytes = kat.ad.hexToBytes()
            let ctBytes = kat.ct.hexToBytes()
            
            var xoodyak = Xoodyak(key: keyBytes, id: [], counter: [])
            xoodyak.absorb(from: nonceBytes)
            xoodyak.absorb(from: adBytes)
            var newCT = [UInt8]()
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

extension String {
    func hexToBytes() -> [UInt8] {
        stride(from: 0, to: count, by: 2).map {
            self[index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: $0 + 2)]
        }.map {
            UInt8($0, radix: 16)!
        }
    }
}
