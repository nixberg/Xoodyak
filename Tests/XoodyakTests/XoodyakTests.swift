import HexString
import XCTest
import Xoodyak

final class XoodyakTests: XCTestCase {
    func testHash() throws {
        struct Vector: Decodable {
            let message: HexString
            let digest:  HexString
            
            private enum CodingKeys: String, CodingKey {
                case message = "msg"
                case digest  = "md"
            }
        }
        
        let url = Bundle.module.url(forResource: "hash", withExtension: "json")
        let vectors = try JSONDecoder().decode([Vector].self, from: try Data(contentsOf: url!))
        
        for vector in vectors {
            var xoodyak = Xoodyak()
            
            xoodyak.absorb(vector.message)
            
            var newDigest = [UInt8](0..<32)
            xoodyak.squeeze(vector.digest.count, to: &newDigest)
            
            XCTAssert(newDigest.dropFirst(32).elementsEqual(vector.digest))
        }
    }
    
    func testAEAD() throws {
        struct Vector: Decodable {
            let key:            HexString
            let nonce:          HexString
            let plaintext:      HexString
            let additionalData: HexString
            let ciphertext:     HexString
            
            private enum CodingKeys: String, CodingKey {
                case key
                case nonce
                case plaintext      = "pt"
                case additionalData = "ad"
                case ciphertext     = "ct"
            }
        }
        
        let url = Bundle.module.url(forResource: "aead", withExtension: "json")
        let vectors = try JSONDecoder().decode([Vector].self, from: try Data(contentsOf: url!))
        
        for vector in vectors {
            let tagByteCount = vector.ciphertext.count - vector.plaintext.count
            
            var encryptor = KeyedXoodyak(key: vector.key)
            encryptor.absorb(vector.nonce)
            encryptor.absorb(vector.additionalData)
            var decryptor = encryptor
            
            var newCiphertext = [UInt8](0..<32)
            encryptor.encrypt(vector.plaintext, to: &newCiphertext)
            encryptor.squeeze(tagByteCount, to: &newCiphertext)
            
            XCTAssert(newCiphertext.dropFirst(32).elementsEqual(vector.ciphertext))
            
            var newPlaintext = [UInt8](0..<32)
            decryptor.decrypt(vector.ciphertext.prefix(vector.plaintext.count), to: &newPlaintext)
            let newTag = decryptor.squeeze(tagByteCount)
            
            XCTAssert(newPlaintext.dropFirst(32).elementsEqual(vector.plaintext))
            XCTAssert(newTag.elementsEqual(vector.ciphertext.suffix(tagByteCount)))
        }
    }
}
