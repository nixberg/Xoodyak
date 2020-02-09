import Foundation
import Xoodoo

enum Flag: UInt8 {
    case zero       = 0x00
    case absorbKey  = 0x02
    case absorb     = 0x03
    case ratchet    = 0x10
    case squeezeKey = 0x20
    case squeeze    = 0x40
    case crypt      = 0x80
}

enum Mode {
    case hash
    case keyed
}

struct Rates {
    static let hash    = 16
    static let input   = 44
    static let output  = 24
    static let ratchet = 16
    
    let absorb: Int
    let squeeze: Int
}

enum Phase {
    case up
    case down
}

public struct Xoodyak {
    let mode: Mode
    let rates: Rates
    var phase = Phase.up
    var xoodoo = Xoodoo()
    
    public init() {
        mode = .hash
        rates = Rates(absorb: Rates.hash, squeeze: Rates.hash)
    }

    public init<K, I, C>(key: K, id: I, counter: C) where K: DataProtocol, I: DataProtocol, C: DataProtocol {
        precondition(key.count + id.count < Rates.input)
        
        mode = .keyed
        rates = Rates(absorb: Rates.input, squeeze: Rates.output)
        
        var data = [UInt8](key)
        data.append(contentsOf: id)
        data.append(UInt8(id.count))
        absorbAny(data, rate: rates.absorb, flag: .absorbKey)
        
        if !counter.isEmpty {
            absorbAny(counter, rate: 1, flag: .zero)
        }
    }
    
    private mutating func down(_ flag: Flag) {
        phase = .down
        xoodoo[0] ^= 0x01
        xoodoo[47] ^= (mode == .hash) ? (flag.rawValue & 0x01) : flag.rawValue
    }
    
    private mutating func down<D>(_ block: D, _ flag: Flag) where D: DataProtocol {
        phase = .down
        for (i, byte) in block.enumerated() {
            xoodoo[i] ^= byte
        }
        xoodoo[block.count] ^= 0x01
        xoodoo[47] ^= (mode == .hash) ? (flag.rawValue & 0x01) : flag.rawValue
    }
    
    private mutating func up(_ flag: Flag) {
        phase = .up
        if mode != .hash {
            xoodoo[47] ^= flag.rawValue
        }
        xoodoo.permute()
    }
    
    private mutating func up<M>(_ count: Int, to block: inout M, _ flag: Flag) where M: MutableDataProtocol {
        up(flag)
        for i in 0..<count {
            block.append(xoodoo[i])
        }
    }
    
    private mutating func absorbAny<D>(_ input: D, rate: Int, flag: Flag) where D: DataProtocol {
        var flag = flag
        for block in input.blocks(rate: rate) {
            if phase != .up {
                up(.zero)
            }
            down(block, flag)
            flag = .zero
        }
    }
    
    private mutating func crypt<D, M>(_ input: D, to output: inout M, decrypt: Bool) where D: DataProtocol, M: MutableDataProtocol {
        var flag = Flag.crypt
        for block in input.blocks(rate: Rates.output) {
            up(flag)
            flag = .zero
            for (i, byte) in block.enumerated() {
                output.append(byte ^ xoodoo[i])
            }
            if decrypt {
                down(output.suffix(block.count), .zero)
            } else {
                down(block, .zero)
            }
        }
    }
    
    private mutating func squeezeAny<M>(_ count: Int, to output: inout M, flag: Flag) where M: MutableDataProtocol  {
        let initialCount = output.count
        up(min(count, rates.squeeze), to: &output, flag)
        while output.count - initialCount < count {
            down(.zero)
            up(min(count - output.count + initialCount, rates.squeeze), to: &output, .zero)
        }
    }
    
    public mutating func absorb<D>(_ input: D) where D: DataProtocol {
        absorbAny(input, rate: rates.absorb, flag: .absorb)
    }
    
    public mutating func encrypt<D, M>(_ plaintext: D, to ciphertext: inout M) where D: DataProtocol, M: MutableDataProtocol {
        precondition(mode == .keyed)
        crypt(plaintext, to: &ciphertext, decrypt: false)
    }
    
    public mutating func decrypt<D, M>(_ ciphertext: D, to plaintext: inout M) where D: DataProtocol, M: MutableDataProtocol {
        precondition(mode == .keyed)
        crypt(ciphertext, to: &plaintext, decrypt: true)
    }
    
    public mutating func squeeze<M>(_ count: Int, to output: inout M) where M: MutableDataProtocol {
        squeezeAny(count, to: &output, flag: .squeeze)
    }
    
    public mutating func squeezeKey<M>(_ count: Int, to output: inout M) where M: MutableDataProtocol {
        precondition(mode == .keyed)
        squeezeAny(count, to: &output, flag: .squeezeKey)
    }
    
    public mutating func ratchet() {
        precondition(mode == .keyed)
        var buffer = [UInt8]()
        squeezeAny(Rates.ratchet, to: &buffer, flag: .ratchet)
        absorbAny(buffer, rate: rates.absorb, flag: .zero)
    }
}

public extension Xoodyak {
    mutating func encrypt<D>(_ plaintext: D) -> [UInt8] where D: DataProtocol {
        var output = [UInt8]()
        output.reserveCapacity(plaintext.count + 16)
        encrypt(plaintext, to: &output)
        return output
    }
    
    mutating func decrypt<D>(_ ciphertext: D) -> [UInt8] where D: DataProtocol {
        var output = [UInt8]()
        output.reserveCapacity(ciphertext.count + 16)
        decrypt(ciphertext, to: &output)
        return output
    }
    
    mutating func squeeze(_ count: Int) -> [UInt8] {
        var output = [UInt8]()
        output.reserveCapacity(count)
        squeeze(count, to: &output)
        return output
    }
    
    mutating func squeezeKey(_ count: Int) -> [UInt8] {
        var output = [UInt8]()
        output.reserveCapacity(count)
        squeezeKey(count, to: &output)
        return output
    }
}
