import XCTest
import Xoodyak

final class XoodyakTests: XCTestCase {
    func testHash() throws {
        struct Vector: Decodable {
            let msg: String
            let md: String
        }
        
        let url = Bundle.module.url(forResource: "hash", withExtension: "json")
        let vectors = try JSONDecoder().decode([Vector].self, from: try Data(contentsOf: url!))
        
        for vector in vectors {
            let message = [UInt8](hex: vector.msg)
            let digest = [UInt8](hex: vector.md)
            
            var xoodyak = Xoodyak()
            xoodyak.absorb(message)
            var newDigest = [UInt8](0..<32)
            xoodyak.squeeze(digest.count, to: &newDigest)
            
            XCTAssertEqual(newDigest.dropFirst(32), digest[...])
        }
    }
    
    func testAEAD() throws {
        struct Vector: Decodable {
            let key: String
            let nonce: String
            let pt: String
            let ad: String
            let ct: String
        }
        
        let url = Bundle.module.url(forResource: "aead", withExtension: "json")
        let vectors = try JSONDecoder().decode([Vector].self, from: try Data(contentsOf: url!))
        
        for vector in vectors  {
            let key = [UInt8](hex: vector.key)
            let nonce = [UInt8](hex: vector.nonce)
            let plaintext = [UInt8](hex: vector.pt)
            let additionalData = [UInt8](hex: vector.ad)
            let ciphertext = [UInt8](hex: vector.ct)
            let tagByteCount = ciphertext.count - plaintext.count
            
            var xoodyak = Xoodyak(key: key, id: [], counter: [])
            xoodyak.absorb(nonce)
            xoodyak.absorb(additionalData)
            var newCiphertext = [UInt8](0..<32)
            xoodyak.encrypt(plaintext, to: &newCiphertext)
            xoodyak.squeeze(tagByteCount, to: &newCiphertext)
            
            XCTAssertEqual(newCiphertext.dropFirst(32), ciphertext[...])
            
            xoodyak = Xoodyak(key: key, id: [], counter: [])
            xoodyak.absorb(nonce)
            xoodyak.absorb(additionalData)
            var newPlaintext = [UInt8](0..<32)
            xoodyak.decrypt(ciphertext.prefix(plaintext.count), to: &newPlaintext)
            let newTag = xoodyak.squeeze(tagByteCount)
            
            XCTAssertEqual(newPlaintext.dropFirst(32), plaintext[...])
            XCTAssertEqual(newTag, ciphertext.suffix(tagByteCount))
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
