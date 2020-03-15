import XCTest
import Xoodyak

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
            let msg = [UInt8](hex: kat.msg)
            let md = [UInt8](hex: kat.md)
            
            var xoodyak = Xoodyak()
            xoodyak.absorb(msg)
            var newMD = [UInt8](0..<32)
            xoodyak.squeeze(md.count, to: &newMD)
            
            XCTAssertEqual(newMD.dropFirst(32), md[...])
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
        
        for kat in kats  {
            let key = [UInt8](hex: kat.key)
            let nonce = [UInt8](hex: kat.nonce)
            let pt = [UInt8](hex: kat.pt)
            let ad = [UInt8](hex: kat.ad)
            let ct = [UInt8](hex: kat.ct)
            let tagCount = ct.count - pt.count
            
            var xoodyak = Xoodyak(key: key, id: [], counter: [])
            xoodyak.absorb(nonce)
            xoodyak.absorb(ad)
            var newCT = [UInt8](0..<32)
            xoodyak.encrypt(pt, to: &newCT)
            xoodyak.squeeze(tagCount, to: &newCT)
            
            XCTAssertEqual(newCT.dropFirst(32), ct[...])
            
            xoodyak = Xoodyak(key: key, id: [], counter: [])
            xoodyak.absorb(nonce)
            xoodyak.absorb(ad)
            var newPT = [UInt8](0..<32)
            xoodyak.decrypt(ct.prefix(pt.count), to: &newPT)
            let newTag = xoodyak.squeeze(tagCount)
            
            XCTAssertEqual(newPT.dropFirst(32), pt[...])
            XCTAssertEqual(newTag, ct.suffix(tagCount))
        }
    }
}

fileprivate extension Array where Element == UInt8 {
    init(hex: String) {
        precondition(hex.count.isMultiple(of: 2))
        var hex = hex[...]
        self = stride(from: 0, to: hex.count, by: 2).map { _ in
            defer { hex = hex.dropFirst(2) }
            return UInt8(hex.prefix(2), radix: 16)!
        }
    }
}
