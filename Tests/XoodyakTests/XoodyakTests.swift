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
            let msg = kat.msg.hexToBytes()
            let md = kat.md.hexToBytes()
            
            var xoodyak = Xoodyak()
            xoodyak.absorb(from: msg)
            var newMD = [UInt8](0..<32)
            xoodyak.squeeze(count: md.count, to: &newMD)
            
            XCTAssertEqual(newMD[32...], md[...])
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
            let key = kat.key.hexToBytes()
            let nonce = kat.nonce.hexToBytes()
            let pt = kat.pt.hexToBytes()
            let ad = kat.ad.hexToBytes()
            let ct = kat.ct.hexToBytes()
            
            var xoodyak = Xoodyak(key: key, id: [], counter: [])
            xoodyak.absorb(from: nonce)
            xoodyak.absorb(from: ad)
            var newCT = [UInt8](0..<32)
            xoodyak.encrypt(from: pt, to: &newCT)
            xoodyak.squeeze(count: 16, to: &newCT)
            
            XCTAssertEqual(newCT[32...], ct[...])
            
            xoodyak = Xoodyak(key: key, id: [], counter: [])
            xoodyak.absorb(from: nonce)
            xoodyak.absorb(from: ad)
            var newPT = [UInt8](0..<32)
            xoodyak.decrypt(from: ct.prefix(pt.count), to: &newPT)
            var newTag = [UInt8]()
            xoodyak.squeeze(count: 16, to: &newTag)
            
            XCTAssertEqual(newPT[32...], pt[...])
            XCTAssertEqual(newTag, ct.suffix(16))
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
