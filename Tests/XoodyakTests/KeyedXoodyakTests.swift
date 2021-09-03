import HexString
import XCTest
import Xoodyak

final class KeyedXoodyakTests: XCTestCase {
    func test() throws {
        struct Vector: Decodable {
            @HexString var key:            [UInt8]
            @HexString var nonce:          [UInt8]
            @HexString var plaintext:      [UInt8]
            @HexString var additionalData: [UInt8]
            @HexString var ciphertext:     [UInt8]
            
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
            encryptor.squeeze(to: &newCiphertext, count: tagByteCount)
            
            XCTAssert(newCiphertext.dropFirst(32).elementsEqual(vector.ciphertext))
            
            var newPlaintext = [UInt8](0..<32)
            decryptor.decrypt(vector.ciphertext.prefix(vector.plaintext.count), to: &newPlaintext)
            let newTag = decryptor.squeeze(count: tagByteCount)
            
            XCTAssert(newPlaintext.dropFirst(32).elementsEqual(vector.plaintext))
            XCTAssert(newTag.elementsEqual(vector.ciphertext.suffix(tagByteCount)))
        }
    }
}
