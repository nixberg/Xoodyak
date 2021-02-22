import XCTest
import Xoodyak

final class XoodyakTests: XCTestCase {
    func testHash() throws {
        struct Vector: Decodable {
            let msg: HexString
            let md: HexString
        }
        
        let url = Bundle.module.url(forResource: "hash", withExtension: "json")
        let vectors = try JSONDecoder().decode([Vector].self, from: try Data(contentsOf: url!))
        
        for vector in vectors {
            var xoodyak = Xoodyak()
            xoodyak.absorb(Array(hexString: vector.msg))
            var newDigest = [UInt8](0..<32)
            xoodyak.squeeze(vector.md.byteCount, to: &newDigest)
            
            XCTAssertEqual(newDigest.dropFirst(32), Array(hexString: vector.md)[...])
        }
    }
    
    func testAEAD() throws {
        struct Vector: Decodable {
            let key: HexString
            let nonce: HexString
            let pt: HexString
            let ad: HexString
            let ct: HexString
        }
        
        let url = Bundle.module.url(forResource: "aead", withExtension: "json")
        let vectors = try JSONDecoder().decode([Vector].self, from: try Data(contentsOf: url!))
        
        for vector in vectors  {
            let key = Array(hexString: vector.key)
            let nonce = Array(hexString: vector.nonce)
            let plaintext = Array(hexString: vector.pt)
            let additionalData = Array(hexString: vector.ad)
            let ciphertext = Array(hexString: vector.ct)
            let tagByteCount = ciphertext.count - plaintext.count
            
            var encryptor = Xoodyak(key: key)
            encryptor.absorb(nonce)
            encryptor.absorb(additionalData)
            var decryptor = encryptor
            
            var newCiphertext = [UInt8](0..<32)
            encryptor.encrypt(plaintext, to: &newCiphertext)
            encryptor.squeeze(tagByteCount, to: &newCiphertext)
            
            XCTAssertEqual(newCiphertext.dropFirst(32), ciphertext[...])
            
            var newPlaintext = [UInt8](0..<32)
            decryptor.decrypt(ciphertext.prefix(plaintext.count), to: &newPlaintext)
            let newTag = decryptor.squeeze(tagByteCount)
            
            XCTAssertEqual(newPlaintext.dropFirst(32), plaintext[...])
            XCTAssertEqual(newTag, ciphertext.suffix(tagByteCount))
        }
    }
}

fileprivate struct HexString: Decodable {
    let value: String
    let byteCount: Int
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
        
        guard value.count.isMultiple(of: 2) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "")
        }
        
        guard value.allSatisfy(\.isHexDigit) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "")
        }
        
        byteCount = value.count / 2
    }
}

fileprivate extension Array where Element == UInt8 {
    init(hexString: HexString) {
        var value = hexString.value[...]
        self = (0..<hexString.byteCount).compactMap { _ in
            defer { value = value.dropFirst(2) }
            return UInt8(value.prefix(2), radix: 16)
        }
    }
}
