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

    public init<K: DataProtocol, ID: DataProtocol, C: DataProtocol>(key: K, id: ID, counter: C) {
        precondition(key.count + id.count <= Rates.input - 1)
        
        mode = .keyed
        rates = Rates(absorb: Rates.input, squeeze: Rates.output)
        
        var data = [UInt8](key)
        data.append(contentsOf: id)
        data.append(UInt8(id.count))
        absorbAny(from: data, rate: rates.absorb, flag: .absorbKey)
        
        if !counter.isEmpty {
            absorbAny(from: counter, rate: 1, flag: .zero)
        }
    }
    
    // Internal interface:
    
    mutating func absorbAny<D: DataProtocol>(from data: D, rate: Int, flag downFlag: Flag) {
        var downFlag = downFlag
        for block in data.blocks(rate: rate) {
            if phase != .up {
                up(flag: .zero)
            }
            down(from: block, flag: downFlag)
            downFlag = .zero
        }
    }
    
    mutating func crypt<D: DataProtocol, M: MutableDataProtocol>(from input: D, to output: inout M, decrypt: Bool) {
        var flag = Flag.crypt
        for block in input.blocks(rate: Rates.output) {
            up(flag: flag)
            flag = .zero
            for (i, byte) in block.enumerated() {
                output.append(byte ^ xoodoo[i])
            }
            if decrypt {
                down(from: output.suffix(block.count), flag: .zero)
            } else {
                down(from: block, flag: .zero)
            }
        }
    }
    
    mutating func squeezeAny<M: MutableDataProtocol>(count: Int, to buffer: inout M, flag upFlag: Flag) {
        up(count: min(count, rates.squeeze), to: &buffer, flag: upFlag)
        while buffer.count < count {
            down(from: [], flag: .zero)
            up(count: min(count - buffer.count, rates.squeeze), to: &buffer, flag: .zero)
        }
    }
    
    mutating func down<D: DataProtocol>(from block: D, flag: Flag) {
        phase = .down
        for (i, byte) in block.enumerated() {
            xoodoo[i] ^= byte
        }
        xoodoo[block.count] ^= 0x01
        xoodoo.last ^= (mode == .hash) ? (flag.rawValue & 0x01) : flag.rawValue
    }
    
    mutating func up(flag: Flag) {
        phase = .up
        if mode != .hash {
            xoodoo.last ^= flag.rawValue
        }
        xoodoo.permute()
    }
    
    mutating func up<M: MutableDataProtocol>(count: Int, to block: inout M, flag: Flag) {
        up(flag: flag)
        for i in 0..<count {
            block.append(xoodoo[i])
        }
    }

    // Public interface:
    
    public mutating func absorb<D: DataProtocol>(from data: D) {
        absorbAny(from: data, rate: rates.absorb, flag: .absorb)
    }
    
    public mutating func encrypt<D: DataProtocol, M: MutableDataProtocol>(from plaintext: D, to ciphertext: inout M) {
        precondition(mode == .keyed)
        crypt(from: plaintext, to: &ciphertext, decrypt: false)
        
    }
    
    public mutating func decrypt<D: DataProtocol, M: MutableDataProtocol>(from ciphertext: D, to plaintext: inout M) {
        precondition(mode == .keyed)
        crypt(from: ciphertext, to: &plaintext, decrypt: true)
    }

    public mutating func squeeze<M: MutableDataProtocol>(count: Int, to buffer: inout M) {
        squeezeAny(count: count, to: &buffer, flag: .squeeze)
    }
    
    public mutating func squeezeKey<M: MutableDataProtocol>(count: Int, to buffer: inout M) {
        precondition(mode == .keyed)
        squeezeAny(count: count, to: &buffer, flag: .squeezeKey)
    }
    
    public mutating func ratchet() {
        precondition(mode == .keyed)
        var buffer = [UInt8]()
        squeezeAny(count: Rates.ratchet, to: &buffer, flag: .ratchet)
        absorbAny(from: buffer, rate: rates.absorb, flag: .zero)
    }
}
