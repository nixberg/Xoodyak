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
        
        let data = try! Data(contentsOf: path(for: "kats/hash.json"))
        let kats = try! JSONDecoder().decode([KAT].self, from: data)
        
        for kat in kats {
            let msgBytes = kat.msg.hexToBytes()
            let mdBytes = kat.md.hexToBytes()
            
            var xoodyak = Xoodyak()
            xoodyak.absorb(from: msgBytes)
            var newMD = [UInt8](0..<32)
            xoodyak.squeeze(count: mdBytes.count, to: &newMD)
            
            XCTAssertEqual(newMD[32...], mdBytes[...])
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
        
        let data = try! Data(contentsOf: path(for: "kats/aead.json"))
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
            var newCT = [UInt8](0..<32)
            xoodyak.encrypt(from: ptBytes, to: &newCT)
            xoodyak.squeeze(count: 16, to: &newCT)
            
            XCTAssertEqual(newCT[32...], ctBytes[...])
            
            xoodyak = Xoodyak(key: keyBytes, id: [], counter: [])
            xoodyak.absorb(from: nonceBytes)
            xoodyak.absorb(from: adBytes)
            var newPT = [UInt8](0..<32)
            xoodyak.decrypt(from: ctBytes.prefix(ptBytes.count), to: &newPT)
            var newTag = [UInt8]()
            xoodyak.squeeze(count: 16, to: &newTag)
            
            XCTAssertEqual(newPT[32...], ptBytes[...])
            XCTAssertEqual(newTag, ctBytes.suffix(16))
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
